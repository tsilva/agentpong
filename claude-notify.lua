--
-- Claude Code Notify - Hammerspoon Module
-- Sends macOS notifications and focuses the correct IDE window across Spaces.
--
-- Usage from CLI:
--   hs -c "claudeNotify('workspace-name', 'Ready for input')"
--

require("hs.ipc")

-- Store notification data: {notification, workspace, spaceId, windowId}
_G._claudeNotifications = _G._claudeNotifications or {}

-- Focus window by going to its space first
local function focusWindow(spaceId, windowId, workspace)
    -- Step 1: Go to the space
    if spaceId then
        hs.spaces.gotoSpace(spaceId)
    end

    -- Step 2: Small delay for space switch animation
    hs.timer.doAfter(0.3, function()
        -- Step 3: Try to focus by window ID first
        local win = windowId and hs.window.get(windowId)

        -- Step 4: If window ID didn't work, search by title
        if not win then
            local app = hs.application.find('Cursor') or hs.application.find('Code')
            if app then
                for _, w in ipairs(app:allWindows()) do
                    if w:title() and w:title():find(workspace, 1, true) then
                        win = w
                        break
                    end
                end
                -- Fallback to first window
                if not win then
                    local wins = app:allWindows()
                    if #wins > 0 then win = wins[1] end
                end
            end
        end

        -- Step 5: Focus the window
        if win then
            win:focus()
        end
    end)
end

-- Main notification function
function claudeNotify(workspace, message)
    workspace = workspace or "Unknown"
    message = message or "Ready for input"

    -- Capture current space and window while we're on the right space
    local currentSpace = hs.spaces.focusedSpace()
    local currentWindowId = nil

    -- Find the window with this workspace in title
    local app = hs.application.find('Cursor') or hs.application.find('Code')
    if app then
        for _, w in ipairs(app:allWindows()) do
            if w:title() and w:title():find(workspace, 1, true) then
                currentWindowId = w:id()
                break
            end
        end
    end

    local notification
    notification = hs.notify.new(function(n)
        -- On click: go to space and focus window
        focusWindow(currentSpace, currentWindowId, workspace)

        -- Clean up
        for i, data in ipairs(_G._claudeNotifications) do
            if data.notification == notification then
                table.remove(_G._claudeNotifications, i)
                break
            end
        end
    end, {
        title = "Claude Code [" .. workspace .. "]",
        informativeText = message,
        soundName = "default",
        withdrawAfter = 0
    })

    -- Store reference to prevent garbage collection
    table.insert(_G._claudeNotifications, {
        notification = notification,
        workspace = workspace,
        spaceId = currentSpace,
        windowId = currentWindowId
    })

    notification:send()
end
