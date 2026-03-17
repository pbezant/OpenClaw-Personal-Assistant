#!/usr/bin/env python3
"""
OpenClaw Discord Bot
Connects the OpenClaw agent system to Discord so Preston can chat with his
jobs, brainstorm, and home-automation agents from any device via Discord.

Usage on the server:
    python discord_bot.py            # start normally
    systemctl start openclaw-bot     # via systemd (preferred)
"""

import os
import asyncio
import textwrap
from pathlib import Path
from collections import defaultdict
from typing import Optional

import discord
from discord import app_commands
from discord.ext import commands
from dotenv import load_dotenv

# ── Bootstrap ────────────────────────────────────────────────────────────────
load_dotenv()

DISCORD_TOKEN: str = os.environ["DISCORD_BOT_TOKEN"]  # required
WORKSPACE     = Path(__file__).parent                  # ~/openclaw/workspace
MAX_HISTORY   = 20          # max messages kept per channel (rolling window)
DISCORD_LIMIT = 1900        # safe Discord message character limit

# Bot owner can restrict the bot to specific guild IDs by setting:
#   ALLOWED_GUILD_IDS=123456789,987654321
_guild_ids_raw = os.getenv("ALLOWED_GUILD_IDS", "")
ALLOWED_GUILD_IDS = (
    [int(g.strip()) for g in _guild_ids_raw.split(",") if g.strip()]
    if _guild_ids_raw else []
)

# ── LLM backend (Anthropic preferred, fallback to OpenAI) ────────────────────
ANTHROPIC_KEY = os.getenv("ANTHROPIC_API_KEY", "")
OPENAI_KEY    = os.getenv("OPENAI_API_KEY", "")

if ANTHROPIC_KEY:
    import anthropic as _anthropic           # type: ignore
    _aclient = _anthropic.Anthropic(api_key=ANTHROPIC_KEY)
    LLM_BACKEND = "anthropic"
    LLM_MODEL   = os.getenv("LLM_MODEL", "claude-3-5-sonnet-20241022")
elif OPENAI_KEY:
    from openai import OpenAI as _OpenAI     # type: ignore
    _aclient = _OpenAI(api_key=OPENAI_KEY)
    LLM_BACKEND = "openai"
    LLM_MODEL   = os.getenv("LLM_MODEL", "gpt-4o")
else:
    raise EnvironmentError(
        "No LLM API key found. Set ANTHROPIC_API_KEY or OPENAI_API_KEY in .env"
    )

# ── Workspace file helpers ────────────────────────────────────────────────────
def _read(relative_path: str, truncate: Optional[int] = None) -> str:
    p = WORKSPACE / relative_path
    if not p.exists():
        return f"[{relative_path} not found]"
    text = p.read_text(encoding="utf-8")
    if truncate and len(text) > truncate:
        text = text[:truncate] + f"\n\n[... truncated to {truncate} chars ...]"
    return text


AGENT_FILES = {
    "jobs":       "agents/jobs.md",
    "brainstorm": "agents/brainstorm.md",
    "home":       "agents/home.md",
}

AGENT_DESCRIPTIONS = {
    "jobs":       "Career assistant — job search, resume, cover letters",
    "brainstorm": "Strategy & planning — ideas, decisions, execution plans",
    "home":       "Home Assistant automation — YAML, triggers, conditions",
}

def build_system_prompt(agent: str) -> str:
    """Assemble system prompt: agent instructions + key context files."""
    agent_instructions = _read(AGENT_FILES.get(agent, AGENT_FILES["jobs"]))
    user  = _read("USER.md")
    goals = _read("GOALS.md")
    tasks = _read("TASKS.md")
    cv    = _read("CV.md", truncate=5000)

    return (
        "You are running as a Discord bot for Preston Bezant's personal assistant "
        "system — OpenClaw.\n\n"
        f"{agent_instructions}\n\n"
        "─── LIVE CONTEXT ───────────────────────────────────────────────────────\n"
        f"# USER PROFILE\n{user}\n\n"
        f"# GOALS\n{goals}\n\n"
        f"# TASKS\n{tasks}\n\n"
        f"# CV (abbreviated)\n{cv}\n"
        "────────────────────────────────────────────────────────────────────────\n\n"
        "You are responding via Discord. Format responses for chat:\n"
        "- Use Discord markdown: **bold**, `code`, ```code blocks```, bullet points\n"
        "- Be concise but complete\n"
        "- If a response must be long, break it into clearly labelled sections\n"
        "- Never exceed 1900 characters in one message; multi-part replies are fine"
    )


# ── In-memory conversation state ─────────────────────────────────────────────
# { channel_id: {"agent": str, "history": [{"role": str, "content": str}]} }
_channel_state: dict = defaultdict(lambda: {"agent": "jobs", "history": []})


def _trim_history(channel_id: int):
    h = _channel_state[channel_id]["history"]
    if len(h) > MAX_HISTORY:
        _channel_state[channel_id]["history"] = h[-MAX_HISTORY:]


# ── LLM call ─────────────────────────────────────────────────────────────────
def _call_llm(system: str, history: list[dict]) -> str:
    """Synchronous LLM call — run in executor to keep Discord async happy."""
    if LLM_BACKEND == "anthropic":
        response = _aclient.messages.create(
            model=LLM_MODEL,
            max_tokens=2048,
            system=system,
            messages=history,
        )
        return response.content[0].text

    # OpenAI
    messages = [{"role": "system", "content": system}] + history
    response = _aclient.chat.completions.create(
        model=LLM_MODEL,
        messages=messages,
        max_tokens=2048,
    )
    return response.choices[0].message.content


async def ask_llm(channel_id: int, user_message: str) -> str:
    """Add user message to history, call LLM, store reply, return text."""
    state = _channel_state[channel_id]
    state["history"].append({"role": "user", "content": user_message})
    _trim_history(channel_id)

    system = build_system_prompt(state["agent"])
    loop   = asyncio.get_event_loop()
    reply  = await loop.run_in_executor(
        None, _call_llm, system, list(state["history"])
    )

    state["history"].append({"role": "assistant", "content": reply})
    _trim_history(channel_id)
    return reply


# ── Discord message splitter ──────────────────────────────────────────────────
def split_message(text: str, limit: int = DISCORD_LIMIT) -> list[str]:
    """Split text at newlines to stay within Discord's character limit."""
    if len(text) <= limit:
        return [text]
    parts = []
    while text:
        if len(text) <= limit:
            parts.append(text)
            break
        split_at = text.rfind("\n", 0, limit)
        if split_at == -1:
            split_at = limit
        parts.append(text[:split_at])
        text = text[split_at:].lstrip("\n")
    return parts


# ── Bot setup ─────────────────────────────────────────────────────────────────
intents = discord.Intents.default()
intents.message_content = True   # needed to read message text

bot = commands.Bot(command_prefix="!", intents=intents)


@bot.event
async def on_ready():
    await bot.tree.sync()  # register slash commands globally
    print(f"[OpenClaw Bot] Logged in as {bot.user} | LLM: {LLM_BACKEND}/{LLM_MODEL}")
    print(f"[OpenClaw Bot] Workspace: {WORKSPACE}")
    if ALLOWED_GUILD_IDS:
        print(f"[OpenClaw Bot] Restricted to guilds: {ALLOWED_GUILD_IDS}")


# ── Guild guard ───────────────────────────────────────────────────────────────
def in_allowed_guild(interaction: discord.Interaction) -> bool:
    if not ALLOWED_GUILD_IDS:
        return True
    return interaction.guild_id in ALLOWED_GUILD_IDS


# ── Slash commands ────────────────────────────────────────────────────────────

@bot.tree.command(name="jobs", description="Switch to the Jobs agent (career, resume, job search)")
@app_commands.describe(message="Optional: your first message to the jobs agent")
async def cmd_jobs(interaction: discord.Interaction, message: Optional[str] = None):
    if not in_allowed_guild(interaction):
        await interaction.response.send_message("🚫 Not authorized.", ephemeral=True)
        return
    _channel_state[interaction.channel_id]["agent"] = "jobs"
    _channel_state[interaction.channel_id]["history"] = []
    if message:
        await interaction.response.defer(thinking=True)
        reply = await ask_llm(interaction.channel_id, message)
        for chunk in split_message(f"**[Jobs Agent]** — context reset\n\n{reply}"):
            await interaction.followup.send(chunk)
    else:
        await interaction.response.send_message(
            "**[Jobs Agent]** activated. History cleared. What would you like to work on?"
        )


@bot.tree.command(name="brainstorm", description="Switch to the Brainstorm agent (strategy, planning, decisions)")
@app_commands.describe(message="Optional: your first message to the brainstorm agent")
async def cmd_brainstorm(interaction: discord.Interaction, message: Optional[str] = None):
    if not in_allowed_guild(interaction):
        await interaction.response.send_message("🚫 Not authorized.", ephemeral=True)
        return
    _channel_state[interaction.channel_id]["agent"] = "brainstorm"
    _channel_state[interaction.channel_id]["history"] = []
    if message:
        await interaction.response.defer(thinking=True)
        reply = await ask_llm(interaction.channel_id, message)
        for chunk in split_message(f"**[Brainstorm Agent]** — context reset\n\n{reply}"):
            await interaction.followup.send(chunk)
    else:
        await interaction.response.send_message(
            "**[Brainstorm Agent]** activated. History cleared. What are we thinking through?"
        )


@bot.tree.command(name="home", description="Switch to the Home agent (Home Assistant automations)")
@app_commands.describe(message="Optional: your first message to the home agent")
async def cmd_home(interaction: discord.Interaction, message: Optional[str] = None):
    if not in_allowed_guild(interaction):
        await interaction.response.send_message("🚫 Not authorized.", ephemeral=True)
        return
    _channel_state[interaction.channel_id]["agent"] = "home"
    _channel_state[interaction.channel_id]["history"] = []
    if message:
        await interaction.response.defer(thinking=True)
        reply = await ask_llm(interaction.channel_id, message)
        for chunk in split_message(f"**[Home Agent]** — context reset\n\n{reply}"):
            await interaction.followup.send(chunk)
    else:
        await interaction.response.send_message(
            "**[Home Agent]** activated. History cleared. What automation are we building?"
        )


@bot.tree.command(name="ask", description="Send a message to the active agent")
@app_commands.describe(message="Your message")
async def cmd_ask(interaction: discord.Interaction, message: str):
    if not in_allowed_guild(interaction):
        await interaction.response.send_message("🚫 Not authorized.", ephemeral=True)
        return
    await interaction.response.defer(thinking=True)
    agent = _channel_state[interaction.channel_id]["agent"]
    reply = await ask_llm(interaction.channel_id, message)
    for chunk in split_message(reply):
        await interaction.followup.send(chunk)


@bot.tree.command(name="clear", description="Clear conversation history for this channel")
async def cmd_clear(interaction: discord.Interaction):
    _channel_state[interaction.channel_id]["history"] = []
    agent = _channel_state[interaction.channel_id]["agent"]
    await interaction.response.send_message(
        f"🗑️ History cleared. Active agent: **{agent}**"
    )


@bot.tree.command(name="status", description="Show active agent and conversation length")
async def cmd_status(interaction: discord.Interaction):
    state = _channel_state[interaction.channel_id]
    agent = state["agent"]
    turns = len(state["history"]) // 2
    desc  = AGENT_DESCRIPTIONS.get(agent, "")
    await interaction.response.send_message(
        f"**Active agent:** `{agent}` — {desc}\n"
        f"**Conversation turns:** {turns}/{MAX_HISTORY // 2}\n"
        f"**LLM:** {LLM_BACKEND} / `{LLM_MODEL}`"
    )


@bot.tree.command(name="agents", description="List all available agents")
async def cmd_agents(interaction: discord.Interaction):
    lines = ["**Available agents:**\n"]
    for name, desc in AGENT_DESCRIPTIONS.items():
        lines.append(f"• **/{name}** — {desc}")
    lines.append("\nUse `/jobs`, `/brainstorm`, or `/home` to switch agents.")
    await interaction.response.send_message("\n".join(lines))


# ── Message handler (DMs + @mentions) ────────────────────────────────────────

@bot.event
async def on_message(message: discord.Message):
    # Ignore own messages
    if message.author == bot.user:
        return

    # Guild restriction
    if ALLOWED_GUILD_IDS and message.guild and message.guild.id not in ALLOWED_GUILD_IDS:
        return

    # Respond in DMs or when @mentioned in a server channel
    is_dm      = isinstance(message.channel, discord.DMChannel)
    is_mention = bot.user in message.mentions

    if not (is_dm or is_mention):
        await bot.process_commands(message)
        return

    # Strip the @mention from the text (if present)
    content = message.content
    if is_mention:
        content = content.replace(f"<@{bot.user.id}>", "").replace(
            f"<@!{bot.user.id}>", ""
        ).strip()

    if not content:
        await message.reply(
            "👋 Hey! Use a slash command like `/jobs`, `/brainstorm`, or `/home` "
            "to set your agent, then just talk to me here or via `/ask`."
        )
        await bot.process_commands(message)
        return

    async with message.channel.typing():
        reply = await ask_llm(message.channel.id, content)

    for chunk in split_message(reply):
        await message.reply(chunk)

    await bot.process_commands(message)


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    bot.run(DISCORD_TOKEN, log_handler=None)
