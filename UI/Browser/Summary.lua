-- Summary tab: where the browser opens. Placeholder until its page is built.
local _, HA = ...

local B = HA.DecorBrowser

local Tab = {}

function Tab.Build() end
function Tab.Show() end
function Tab.Hide() end
function Tab.Refresh() end
function Tab.SetCombat() end

B.RegisterTab("summary", Tab)
