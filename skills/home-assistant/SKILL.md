# Skill: Home Assistant Integration

This skill's purpose is to connect to and manage a Home Assistant instance.

## Primary Goal: Suggest Automations

This skill can discover your Home Assistant devices and suggest useful automations based on your live setup, posting suggestions directly to a designated Discord channel.

### Configuration

1.  **Home Assistant URL:** (e.g., `http://homeassistant.local:8123`, `http://192.168.1.205:8123`, or your external access URL). Store securely in `memory/home_assistant_url.md`.
2.  **Long-Lived Access Token:** This token acts as a password for API access.
    *   **How to Generate:** In Home Assistant, go to your **Profile** (bottom left), scroll to "Long-Lived Access Tokens," and click "CREATE TOKEN." Copy it immediately!
    *   **How to Provide:** Store this token securely in `memory/home_assistant_token.md`.
3.  **Discord Channel ID for Suggestions:** The numerical ID of the Discord channel where automation suggestions should be posted. Store securely in `memory/home_assistant_discord_channel_id.md`.

### Workflow

1.  **Connect and Identify Devices:**
    *   Before suggesting automations, ensure the Home Assistant URL and token are provided.
    *   Use the `scripts/get_ha_entities.py` script to fetch a live list of your connected devices and entities.
    *   Example invocation (assuming `ha_url` and `ha_token` are retrieved from memory):
        ```python
        print(default_api.exec(command=f"python3 ~/openclaw/workspace/skills/home-assistant/scripts/get_ha_entities.py --ha_url \"{ha_url}\" --ha_token \"{ha_token}\""))
        ```
    *   Analyze the fetched entity list to understand your smart home setup.

2.  **Research Automations:**
    *   Based on your identified devices and entities, use `web_search` to find creative and practical automation recipes.
    *   Focus on automations that enhance convenience, security, or energy efficiency.
    *   Search queries should be specific, incorporating your actual devices (e.g., "home assistant automation ideas for living room motion sensor and philips hue lights").

3.  **Structure the Suggestion:** Format the findings into a clear, structured format that is easy to understand. Each suggestion should include:
    -   **Name:** A clear, descriptive name for the automation (e.g., "Welcome Home Lighting").
    -   **Goal:** A one-sentence description of what it does.
    -   **Trigger:** The event that starts the automation (e.g., "Front door unlocks").
    -   **Condition(s):** (Optional) The conditions that must be true (e.g., "Sun is below horizon").
    -   **Action(s):** The steps the automation performs (e.g., "Turn on entryway lights, set to 80% brightness").

4.  **Save and Notify:**
    *   Append the structured suggestion to the `home_assistant/AUTOMATION_SUGGESTIONS.md` file.
    *   Retrieve the Discord Channel ID from `memory/home_assistant_discord_channel_id.md`.
    *   Send a message to the specified Discord channel using the `message` tool with `action="send"` and `to="[channel_id]"`, notifying the user that a new suggestion has been added. Suggest using a thread for discussion.

## Advanced Capabilities (Future)
-   Implement automations directly via the HA API or by generating YAML/Node-RED flows.
