Drogua.app():setLogPath("./"):setLogLevel("WARN"):addListener("0.0.0.0", 5555):setThreadNum(2):loadJsonConfig("config")

Drogua.print("Drogua SMARTcheck API started!")

-- ============================================================
-- SMART Disk Monitor API
-- ============================================================

Drogua.Routes.getAsync("/logs", function(req)
    -- Get limit from query string, default to 30
    local limit_str = req:query("limit") or "30"
    local limit = tonumber(limit_str) or 30
    local output_dir = "logs"

    local logs = {}

    -- List all .txt files in the logs directory
    -- Linux/macOS compatible
    -- Windows alternative:
    -- 'dir /b "' .. output_dir .. '\\*.txt" 2>nul'
    local handle = io.popen('ls -1 "' .. output_dir .. '"/*.txt 2>/dev/null')

    if handle then
        local result = handle:read("*a")
        handle:close()

        for filepath in result:gmatch("[^\r\n]+") do

            -- Extract just the filename from the path
            local basename = filepath:match("([^/\\]+)$")

            if basename and basename:match("%.txt$") then

                -- Extract year, month, and day
                -- Lua strings are 1-indexed
                local year = tonumber(basename:sub(1, 4))
                local month = tonumber(basename:sub(6, 7))
                local day = tonumber(basename:sub(9, 10))

                if year and month and day then

                    local attributes = {}
                    local file = io.open(filepath, "r")

                    if file then

                        for line in file:lines() do

                            -- Strip leading/trailing whitespace
                            line = line:match("^%s*(.-)%s*$")

                            -- Check if line starts with a digit
                            if line ~= "" and line:match("^%d") then

                                -- Split into 9 words and the remaining text
                                local p1, p2, p3, p4, p5, p6, p7, p8, p9, p10 = line:match(
                                    "^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.*)$")

                                if p1 then
                                    attributes[p2] = {
                                        id = tonumber(p1),
                                        flag = p3,
                                        value = tonumber(p4),
                                        worst = tonumber(p5),
                                        thresh = p6,
                                        type = p7,
                                        updated = p8,
                                        when_failed = p9,
                                        raw_value = p10
                                    }
                                end
                            end
                        end

                        file:close()
                    end

                    -- Extract required metrics safely (fallback to 0)

                    -- Temperature
                    local temp_attr = attributes["Temperature_Celsius"]
                    local temperature = 0

                    if temp_attr and temp_attr.raw_value then
                        local first_word = temp_attr.raw_value:match("^%s*(%S+)")
                        temperature = tonumber(first_word) or 0
                    end

                    -- Power-on hours
                    local poh_attr = attributes["Power_On_Hours"]
                    local power_on_hours = tonumber(poh_attr and poh_attr.raw_value) or 0

                    -- Media wearout indicator
                    local wear_attr = attributes["Media_Wearout_Indicator"]
                    local wear_percent = tonumber(wear_attr and wear_attr.value) or 0

                    -- Power cycle count
                    local cycles_attr = attributes["Power_Cycle_Count"]
                    local power_cycles = tonumber(cycles_attr and cycles_attr.raw_value) or 0

                    -- Add log entry
                    table.insert(logs, {
                        year = year,
                        month = month,
                        day = day,
                        temperature = temperature,
                        power_on_hours = power_on_hours,
                        wear_percent = wear_percent,
                        power_cycles = power_cycles
                    })

                end
            end
        end
    end

    -- Sort logs by date descending (newest first)
    table.sort(logs, function(a, b)
        if a.year ~= b.year then
            return a.year > b.year
        end

        if a.month ~= b.month then
            return a.month > b.month
        end

        return a.day > b.day
    end)

    -- Apply limit
    -- 0 or less means return all logs
    if limit <= 0 then
        return logs
    else
        local result = {}
        local max_items = math.min(limit, #logs)

        for i = 1, max_items do
            table.insert(result, logs[i])
        end

        return result
    end

end)

Drogua.app():run()
