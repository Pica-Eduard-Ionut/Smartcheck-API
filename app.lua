Drogua.app():setLogPath("./"):setLogLevel("WARN"):addListener("0.0.0.0", 5555):setThreadNum(2):loadJsonConfig("config")

Drogua.print("Drogua SMARTcheck API started!")

-- ============================================================
-- SMART Disk Monitor API
-- ============================================================

local OUTPUT_DIR = "./logs"

-- ============================================================
-- Extract integer from a string
-- ============================================================

local function extractNumber(value)
    if not value then
        return 0
    end

    local number = tostring(value):match("^%s*([+-]?%d+)")

    return tonumber(number) or 0
end

-- ============================================================
-- Parse SMART attribute line
-- ============================================================

local function parseAttribute(line)
    local id, name, flag, value, worst, thresh, attr_type, updated, when_failed, raw_value =
        line:match("^%s*(%d+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(.+)$")

    if not id then
        return nil, nil
    end

    return name, {
        id = tonumber(id),
        flag = flag,
        value = tonumber(value) or 0,
        worst = tonumber(worst) or 0,
        thresh = thresh,
        type = attr_type,
        updated = updated,
        when_failed = when_failed,
        raw_value = raw_value
    }
end

-- ============================================================
-- Read SMART attributes from file
-- ============================================================

local function readSmartFile(filepath)
    local attributes = {}

    local file, err = io.open(filepath, "r")

    if not file then
        Drogua.print("Cannot open file: " .. filepath .. " (" .. tostring(err) .. ")")

        return attributes
    end

    for original_line in file:lines() do
        -- IMPORTANT:
        -- Never modify the generic-for loop variable.
        -- Drogua treats it as a const variable.

        local line = original_line:match("^%s*(.-)%s*$")

        if line ~= "" and line:match("^%d+%s+") then
            local name, attribute = parseAttribute(line)

            if name then
                attributes[name] = attribute
            end
        end
    end

    file:close()

    return attributes
end

-- ============================================================
-- Get raw SMART attribute value
-- ============================================================

local function getRaw(attributes, name)
    local attribute = attributes[name]

    if not attribute then
        return 0
    end

    return extractNumber(attribute.raw_value)
end

-- ============================================================
-- SMART Logs API
-- ============================================================

Drogua.Routes.getAsync(
    "/logs",
    function(req)
        -- Read query parameter
        local limit = tonumber(req:query("limit")) or 30

        -- Validate limit
        if limit ~= limit or limit == math.huge or limit == -math.huge then
            limit = 30
        end

        limit = math.floor(limit)

        local logs = {}

        -- ========================================================
        -- Find log files
        -- ========================================================

        local command = 'ls -1 "' .. OUTPUT_DIR .. '"/*.txt 2>/dev/null'

        local handle = io.popen(command)

        if not handle then
            Drogua.print("ERROR: Unable to list log directory")
            return logs
        end

        local files = {}

        for filepath in handle:lines() do
            table.insert(files, filepath)
        end

        handle:close()

        -- ========================================================
        -- Process log files
        -- ========================================================

        for _, filepath in ipairs(files) do
            local filename = filepath:match("([^/\\]+)$")

            if filename then
                -- Expected filename: YYYY-MM-DD.txt

                local year_str, month_str, day_str = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%.txt$")

                local year = tonumber(year_str)
                local month = tonumber(month_str)
                local day = tonumber(day_str)

                if year and month and day and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                    local attributes = readSmartFile(filepath)

                    -- Temperature
                    local temp = attributes["Temperature_Celsius"]

                    local temperature = temp and extractNumber(temp.raw_value) or 0

                    -- Power-on hours
                    local power_on_hours = getRaw(attributes, "Power_On_Hours")

                    -- SSD wear percentage
                    local wear = attributes["Media_Wearout_Indicator"]

                    local wear_percent = wear and (tonumber(wear.value) or 0) or 0

                    -- Power cycles
                    local power_cycles = getRaw(attributes, "Power_Cycle_Count")

                    -- Add log entry
                    table.insert(
                        logs,
                        {
                            year = year,
                            month = month,
                            day = day,
                            temperature = temperature,
                            power_on_hours = power_on_hours,
                            wear_percent = wear_percent,
                            power_cycles = power_cycles
                        }
                    )
                end
            end
        end

        -- ========================================================
        -- Sort newest first
        -- ========================================================

        table.sort(
            logs,
            function(a, b)
                if a.year ~= b.year then
                    return a.year > b.year
                end

                if a.month ~= b.month then
                    return a.month > b.month
                end

                return a.day > b.day
            end
        )

        -- ========================================================
        -- Apply limit
        -- ========================================================

        -- 0 or negative = return all logs

        if limit <= 0 then
            return logs
        end

        local result = {}

        local max_items = math.min(limit, #logs)

        for i = 1, max_items do
            result[#result + 1] = logs[i]
        end

        return result
    end
)

-- ============================================================
-- Start application
-- ============================================================

Drogua.app():run()
