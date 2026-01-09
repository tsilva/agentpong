--
-- Claude Code Notify - Hammerspoon Module
-- Sends macOS notifications and focuses the correct IDE window across Spaces.
--
-- Usage from CLI:
--   hs -c "claudeNotify('workspace-name', 'Ready for input')"
--
-- Setup:
--   1. Copy this file to ~/.hammerspoon/
--   2. Add require("claude-notify") to ~/.hammerspoon/init.lua
--   3. Reload Hammerspoon config
--

-- Required for CLI communication
require("hs.ipc")

-- Apps to search for windows (Cursor and VS Code)
local TARGET_APPS = {"Cursor", "Code"}

-- Find a window matching the workspace name across all Spaces
local function findWorkspaceWindow(workspace)
    -- Create a window filter for target apps
    -- Note: hs.window.filter can see windows across all Spaces
    local wf = hs.window.filter.new(TARGET_APPS)
    local windows = wf:getWindows()

    for _, win in ipairs(windows) do
        local title = win:title() or ""
        if string.find(title, workspace, 1, true) then
            return win
        end
    end

    -- Fallback: if no exact match, try to find any window from target apps
    if #windows > 0 then
        return windows[1]
    end

    return nil
end

-- Send notification and focus window on click
function claudeNotify(workspace, message)
    workspace = workspace or "Unknown"
    message = message or "Ready for input"

    local notification = hs.notify.new(function(n)
        -- This callback fires when the notification is clicked
        local win = findWorkspaceWindow(workspace)
        if win then
            -- focus() switches to the window's Space and focuses it
            win:focus()
        else
            -- Fallback: try to activate the first target app we find
            for _, appName in ipairs(TARGET_APPS) do
                local app = hs.application.find(appName)
                if app then
                    app:activate()
                    break
                end
            end
        end
    end, {
        title = "Claude Code [" .. workspace .. "]",
        informativeText = message,
        soundName = "default",
        withdrawAfter = 0  -- Keep notification until user interacts
    })

    notification:send()
end
