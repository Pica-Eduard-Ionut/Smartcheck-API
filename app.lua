Drogua.app():setLogPath("./"):setLogLevel("WARN"):addListener("0.0.0.0", 5555):setThreadNum(2):loadJsonConfig("config")

Drogua.print("Drogua SMARTcheck API started!")

-- ============================================================
-- SMART Disk Monitor API
-- ============================================================

local OUTPUT_DIR = "./logs"

-- Extract an integer from a value, even if extra text follows.
local function extractNumber(value)
    if not value then
        return 0
    end

    local number = tostring(value):match("^%s*([+-]?%d+)")
    return tonumber(number) or 0
end

-- Parse a SMART attribute line.
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

-- Read all SMART attributes from one file.
local function readSmartFile(filepath)
    local attributes = {}

    local file, err = io.open(filepath, "r")

    if not file then
        Drogua.print("Cannot open file: " .. filepath .. " (" .. tostring(err) .. ")")
        return attributes
    end

    for line in file:lines() do
        line = line:match("^%s*(.-)%s*$")

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

-- Get one metric safely.
local function getRaw(attributes, name)
    local attribute = attributes[name]

    if not attribute then
        return 0
    end

    return extractNumber(attribute.raw_value)
end

Drogua.Routes.getAsync(
    "/logs",
    function(req)
        -- Query parameter
        local limit = tonumber(req:query("limit")) or 30

        -- Reject NaN/infinite values and normalize fractional limits.
        if limit ~= limit or limit == math.huge or limit == -math.huge then
            limit = 30
        end

        limit = math.floor(limit)

        local logs = {}

        -- Find TXT files.
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

        -- Read files.
        for _, filepath in ipairs(files) do
            local filename = filepath:match("([^/\\]+)$")

            if filename then
                local year, month, day = filename:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%.txt$")

                year = tonumber(year)
                month = tonumber(month)
                day = tonumber(day)

                if year and month and day and month >= 1 and month <= 12 and day >= 1 and day <= 31 then
                    local attributes = readSmartFile(filepath)

                    local temp = attributes["Temperature_Celsius"]
                    local wear = attributes["Media_Wearout_Indicator"]

                    table.insert(
                        logs,
                        {
                            year = year,
                            month = month,
                            day = day,
                            temperature = temp and extractNumber(temp.raw_value) or 0,
                            power_on_hours = getRaw(attributes, "Power_On_Hours"),
                            wear_percent = wear and (tonumber(wear.value) or 0) or 0,
                            power_cycles = getRaw(attributes, "Power_Cycle_Count")
                        }
                    )
                end
            end
        end

        -- Newest first.
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

        -- Limit <= 0 means return everything.
        if limit <= 0 then
            return logs
        end

        local result = {}

        for i = 1, math.min(limit, #logs) do
            result[#result + 1] = logs[i]
        end

        return result
    end
)

Drogua.app():run()
