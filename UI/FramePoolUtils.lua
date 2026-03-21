--[[
    Homestead - FramePoolUtils
    Shared frame-pool primitives used by HomesteadWorldMapProvider and
    HomesteadMinimapOverlay.

    Pure utility module — no events, no SavedVariables, no Initialize().
]]

local _, HA = ...

local FramePoolUtils = {}
HA.FramePoolUtils = FramePoolUtils

local pairs = pairs

function FramePoolUtils.BoolToKey(value)
    return value and "1" or "0"
end

function FramePoolUtils.AcquirePooledFrame(poolByKey, poolKey, createFunc)
    local bucket = poolByKey[poolKey]
    if bucket then
        local idx = #bucket
        if idx > 0 then
            local frame = bucket[idx]
            bucket[idx] = nil
            frame.__hsInPool = false
            frame.__hsPoolKey = poolKey
            return frame
        end
    end

    local frame = createFunc()
    frame.__hsInPool = false
    frame.__hsPoolKey = poolKey
    return frame
end

function FramePoolUtils.ReleasePooledFrame(poolByKey, frame, cleanupFunc)
    if not frame or frame.__hsInPool then
        return
    end

    if cleanupFunc then
        cleanupFunc(frame)
    end

    local poolKey = frame.__hsPoolKey
    if not poolKey then
        return
    end

    local bucket = poolByKey[poolKey]
    if not bucket then
        bucket = {}
        poolByKey[poolKey] = bucket
    end

    frame.__hsInPool = true
    bucket[#bucket + 1] = frame
end

function FramePoolUtils.FlushPoolBuckets(poolByKey, cleanupFunc)
    for poolKey, bucket in pairs(poolByKey) do
        for i = #bucket, 1, -1 do
            local frame = bucket[i]
            if frame then
                if cleanupFunc then
                    cleanupFunc(frame)
                end
                frame.__hsInPool = false
                frame.__hsPoolKey = nil
            end
            bucket[i] = nil
        end
        poolByKey[poolKey] = nil
    end
end
