-- ========== 服务端逻辑 ==========
if CLIENT then return end
--[[ 服务端主导的AIO解绑系统 ]]--
local NPC_ID = 12345
local NEED_MONEY = 30000000
local DB_TABLE = "_解绑_配置"
local LOG_TABLE = "_解绑_日志"

-- ========== 服务端逻辑 ==========
if CLIENT then return end

-- 数据库操作函数
local function getUnbindConfig(itemEntry)
    local query = ("SELECT requiredItem, requiredItemCount FROM `%s` WHERE itemEntry = %d"):format(DB_TABLE, itemEntry)
    local result = WorldDBQuery(query)
    return result and result:GetInt32(0), result and result:GetInt32(1)
end

local function logUnbind(player, itemEntry)
    WorldDBExecute(("INSERT INTO `%s` (playerGUID, itemEntry) VALUES (%d, %d)"):format(LOG_TABLE, player:GetGUIDLow(), itemEntry))
end

-- NPC交互
RegisterCreatureGossipEvent(NPC_ID, 1, function(event, player, unit)
    player:GossipMenuAddItem(0, "我要解绑装备", 0, 1)
    player:GossipSendMenu(1, unit)
end)

-- 修正NPC交互部分：确保player对象有效
RegisterCreatureGossipEvent(NPC_ID, 2, function(event, player, unit, sender, intid, code)
    if intid == 1 then
        if not player or not player:IsPlayer() then -- 添加有效性检查
            return
        end
        -- 发送UI框架到客户端
        AIO.Send(player, "UnbindUI_Create", [[...]]) -- 确保player有效
        player:GossipComplete()
    end
end)

-- ========== 通信处理 ==========
AIO.Handle("UnbindUI_CheckItem", function(player, itemLink)
    if not player or not player:IsPlayer() then
        return -- 防止无效的player对象
    end
    local itemEntry = itemLink:match("item:(%d+)")
    local reqItem, reqCount = getUnbindConfig(tonumber(itemEntry))
    
    if reqItem then
        local hasCount = player:GetItemCount(reqItem)
        AIO.Send(player, "UnbindUI_Update", reqItem, reqCount, hasCount)
    else
        AIO.Send(player, "UnbindUI_Message", "该物品不能解绑", 1, 0, 0)
    end
end)

AIO.Handle("UnbindUI_Confirm", function(player, itemLink)
    if not player or not player:IsPlayer() then
        return -- 防止无效的player对象
    end
    local itemEntry = itemLink:match("item:(%d+)")
    local reqItem, reqCount = getUnbindConfig(tonumber(itemEntry))
    
    -- 验证材料
    if not reqItem or player:GetItemCount(reqItem) < reqCount then
        AIO.Send(player, "UnbindUI_Message", "材料不足！", 1, 0, 0)
        return
    end
    
    -- 验证金币
    if player:GetCoinage() < NEED_MONEY then
        AIO.Send(player, "UnbindUI_Message", "金币不足！", 1, 0, 0)
        return
    end
    
    -- 执行解绑
    player:ModifyMoney(-NEED_MONEY)
    player:RemoveItem(reqItem, reqCount)
    local item = player:GetItemByEntry(itemEntry)
    if item then
        item:SetBinding(false)
    end
    logUnbind(player, itemEntry)
    
    AIO.Send(player, "UnbindUI_Message", "解绑成功！", 0, 1, 0)
    AIO.Send(player, "UnbindUI_Hide")
end)