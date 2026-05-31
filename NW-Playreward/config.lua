Config = {}

Config.Debug = false

-- Seconds between each online-time tick.
Config.TickInterval = 60

-- Seconds between each database save for active players.
Config.SaveInterval = 120

-- 24 hours real-life reset window.
Config.ResetAfterSeconds = 24 * 60 * 60

-- Milestones are in hours.
Config.Milestones = { 1, 3, 6, 9, 12 }

-- Add or change rewards per milestone hour.
-- Supported types:
-- 1) money: { type = 'money', account = 'money'|'bank'|'black_money', amount = 5000, label = '...' }
-- 2) item:  { type = 'item',  name = 'water', count = 2, metadata = {}, label = '...' }
Config.Rewards = {
    [1] = {
        { type = 'money', account = 'money', amount = 5000, label = '5,000 DKK' }
    },
    [3] = {
        { type = 'money', account = 'bank', amount = 12500, label = '12,500 DKK' }
    },
    [6] = {
        { type = 'money', account = 'bank', amount = 25000, label = '25,000 DKK' }
    },
    [9] = {
        { type = 'money', account = 'bank', amount = 40000, label = '40,000 DKK' }
    },
    [12] = {
        { type = 'money', account = 'bank', amount = 60000, label = '60,000 DKK' }
    }
}

Config.Messages = {
    Reset = 'Din aktivitetstid blev nulstillet (24 timer).',
    Milestone = 'Du fik reward for %s timers aktivitet: %s',
    RewardBlocked = 'Kunne ikke give reward endnu: %s'
}
