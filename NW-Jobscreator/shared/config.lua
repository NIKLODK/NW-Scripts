Config = {}

-- Framework mode:
-- - 'esx' (default): reads/writes ESX jobs + grades tables and calls ESX refresh when available.
-- - 'none': only manages DB tables (jobs/job_grades) without framework integration.
Config.Framework = 'esx'

-- ESX table/column defaults (works with most ESX legacy schemas).
Config.ESX = {
  jobsTable = 'jobs',
  jobGradesTable = 'job_grades',
  jobsColumns = {
    name = 'name',
    label = 'label',
    whitelisted = 'whitelisted' -- optional; will be ignored if missing
  },
  jobGradesColumns = {
    jobName = 'job_name',
    grade = 'grade',
    name = 'name',
    label = 'label',
    salary = 'salary',
    skinMale = 'skin_male',     -- optional
    skinFemale = 'skin_female'  -- optional
  }
}

-- Admin access options (any of these can grant access):
-- - ACE permission (recommended)
-- - Discord ID allowlist (player must have Discord identifier enabled)
-- - ESX group allowlist (admin/superadmin/etc)
Config.Admin = {
  ace = 'jobscreator.admin',
  discordIds = {
    '291255160590827520',
  },
  esxGroups = {
    'admin',
    'superadmin'
  }
}

-- Backwards-compatible alias (older code used Config.AdminAce)
Config.AdminAce = Config.Admin.ace

-- Boss menu interaction defaults
Config.BossMenus = {
  textInteractDistance = 2.0,
  markerDistance = 20.0,
  interactKey = 38, -- E
  defaultZoneRadius = 1.5
}

-- Society / company money (ESX addonaccount/esx_society)
Config.Society = {
  enabled = true,
  accountPrefix = 'society_',
  moneySource = 'cash', -- 'cash' or 'bank'
  unemployedJob = 'unemployed',
  unemployedGrade = 0
}

-- Users table (for employee listing / offline management)
Config.UsersTable = {
  table = 'users',
  identifier = 'identifier',
  job = 'job',
  jobGrade = 'job_grade',
  firstname = 'firstname',
  lastname = 'lastname',
  name = 'name' -- some servers have a single name column instead
}
