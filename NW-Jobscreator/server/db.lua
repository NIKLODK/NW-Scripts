local Utils = lib.require('shared.utils')

local DB = {}

local function ident(s)
  -- Basic identifier safety: only allow letters, numbers, underscore.
  if type(s) ~= 'string' or s:match('^[%w_]+$') == nil then
    error(('invalid sql identifier: %s'):format(tostring(s)))
  end
  return ('`%s`'):format(s)
end

local function col(tbl, c)
  return ident((tbl or {})[c] or c)
end

local function tableName(s)
  return ident(s)
end

local function maybeHasColumn(tableNameRaw, columnNameRaw)
  local r = MySQL.query.await('SHOW COLUMNS FROM ' .. tableName(tableNameRaw) .. ' LIKE ?', { columnNameRaw })
  return r and #r > 0
end

function DB.fetchJobsWithGrades()
  local esx = Config.ESX
  local jobsT = esx.jobsTable
  local gradesT = esx.jobGradesTable

  local jobs = MySQL.query.await(
    ('SELECT %s AS name, %s AS label FROM %s ORDER BY %s ASC'):format(
      col(esx.jobsColumns, 'name'),
      col(esx.jobsColumns, 'label'),
      tableName(jobsT),
      col(esx.jobsColumns, 'name')
    )
  ) or {}

  local grades = MySQL.query.await(
    ('SELECT %s AS job_name, %s AS grade, %s AS name, %s AS label, %s AS salary FROM %s ORDER BY %s ASC, %s ASC'):format(
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade'),
      col(esx.jobGradesColumns, 'name'),
      col(esx.jobGradesColumns, 'label'),
      col(esx.jobGradesColumns, 'salary'),
      tableName(gradesT),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    )
  ) or {}

  return jobs, grades
end

function DB.createJob(name, label)
  local esx = Config.ESX
  local jobsT = esx.jobsTable

  if not Utils.isValidName(name) then return false, 'Ugyldigt jobnavn.' end
  if not Utils.isValidLabel(label) then return false, 'Ugyldig job label.' end

  local exists = MySQL.scalar.await(
    ('SELECT 1 FROM %s WHERE %s = ? LIMIT 1'):format(
      tableName(jobsT),
      col(esx.jobsColumns, 'name')
    ),
    { name }
  )
  if exists then return false, 'Job findes allerede.' end

  local hasWhitelist = false
  pcall(function()
    hasWhitelist = maybeHasColumn(jobsT, esx.jobsColumns.whitelisted or 'whitelisted')
  end)

  if hasWhitelist then
    MySQL.insert.await(
      ('INSERT INTO %s (%s, %s, %s) VALUES (?, ?, 0)'):format(
        tableName(jobsT),
        col(esx.jobsColumns, 'name'),
        col(esx.jobsColumns, 'label'),
        col(esx.jobsColumns, 'whitelisted')
      ),
      { name, label }
    )
  else
    MySQL.insert.await(
      ('INSERT INTO %s (%s, %s) VALUES (?, ?)'):format(
        tableName(jobsT),
        col(esx.jobsColumns, 'name'),
        col(esx.jobsColumns, 'label')
      ),
      { name, label }
    )
  end

  -- Ensure at least grade 0 exists.
  DB.createGrade(name, 0, 'recruit', 'Rekrut', 0)
  return true
end

function DB.updateJobLabel(name, newLabel)
  local esx = Config.ESX
  if not Utils.isValidName(name) then return false, 'Ugyldigt jobnavn.' end
  if not Utils.isValidLabel(newLabel) then return false, 'Ugyldig label.' end

  local jobsT = esx.jobsTable
  MySQL.update.await(
    ('UPDATE %s SET %s = ? WHERE %s = ?'):format(
      tableName(jobsT),
      col(esx.jobsColumns, 'label'),
      col(esx.jobsColumns, 'name')
    ),
    { newLabel, name }
  )
  return true
end

function DB.deleteJob(name)
  local esx = Config.ESX
  if not Utils.isValidName(name) then return false, 'Ugyldigt jobnavn.' end

  local jobsT = esx.jobsTable
  local gradesT = esx.jobGradesTable

  MySQL.transaction.await({
    {
      query = ('DELETE FROM %s WHERE %s = ?'):format(tableName(gradesT), col(esx.jobGradesColumns, 'jobName')),
      values = { name }
    },
    {
      query = ('DELETE FROM %s WHERE %s = ?'):format(tableName(jobsT), col(esx.jobsColumns, 'name')),
      values = { name }
    }
  })
  return true
end

function DB.createGrade(jobName, grade, name, label, salary)
  local esx = Config.ESX
  local gradesT = esx.jobGradesTable

  if not Utils.isValidName(jobName) then return false, 'Ugyldigt job.' end
  if type(grade) ~= 'number' or grade < 0 then return false, 'Ugyldig rang.' end
  if not Utils.isValidName(name) then return false, 'Ugyldigt rang-navn.' end
  if not Utils.isValidLabel(label) then return false, 'Ugyldig rang label.' end
  salary = Utils.ensureNumber(salary, 0)

  local exists = MySQL.scalar.await(
    ('SELECT 1 FROM %s WHERE %s = ? AND %s = ? LIMIT 1'):format(
      tableName(gradesT),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    ),
    { jobName, grade }
  )
  if exists then return false, 'Rang findes allerede.' end

  local hasSkinMale, hasSkinFemale = false, false
  pcall(function()
    hasSkinMale = maybeHasColumn(gradesT, esx.jobGradesColumns.skinMale or 'skin_male')
    hasSkinFemale = maybeHasColumn(gradesT, esx.jobGradesColumns.skinFemale or 'skin_female')
  end)

  if hasSkinMale and hasSkinFemale then
    MySQL.insert.await(
      ('INSERT INTO %s (%s, %s, %s, %s, %s, %s, %s) VALUES (?, ?, ?, ?, ?, ?, ?)'):format(
        tableName(gradesT),
        col(esx.jobGradesColumns, 'jobName'),
        col(esx.jobGradesColumns, 'grade'),
        col(esx.jobGradesColumns, 'name'),
        col(esx.jobGradesColumns, 'label'),
        col(esx.jobGradesColumns, 'salary'),
        col(esx.jobGradesColumns, 'skinMale'),
        col(esx.jobGradesColumns, 'skinFemale')
      ),
      { jobName, grade, name, label, salary, '{}', '{}' }
    )
  else
    MySQL.insert.await(
      ('INSERT INTO %s (%s, %s, %s, %s, %s) VALUES (?, ?, ?, ?, ?)'):format(
        tableName(gradesT),
        col(esx.jobGradesColumns, 'jobName'),
        col(esx.jobGradesColumns, 'grade'),
        col(esx.jobGradesColumns, 'name'),
        col(esx.jobGradesColumns, 'label'),
        col(esx.jobGradesColumns, 'salary')
      ),
      { jobName, grade, name, label, salary }
    )
  end

  return true
end

function DB.updateGrade(jobName, grade, newLabel, newSalary)
  local esx = Config.ESX
  if not Utils.isValidName(jobName) then return false, 'Ugyldigt job.' end
  grade = tonumber(grade)
  if not grade or grade < 0 then return false, 'Ugyldig rang.' end
  if not Utils.isValidLabel(newLabel) then return false, 'Ugyldig label.' end
  newSalary = Utils.ensureNumber(newSalary, 0)

  local gradesT = esx.jobGradesTable
  MySQL.update.await(
    ('UPDATE %s SET %s = ?, %s = ? WHERE %s = ? AND %s = ?'):format(
      tableName(gradesT),
      col(esx.jobGradesColumns, 'label'),
      col(esx.jobGradesColumns, 'salary'),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    ),
    { newLabel, newSalary, jobName, grade }
  )
  return true
end

function DB.updateGradeSalary(jobName, grade, salary)
  local esx = Config.ESX
  if not Utils.isValidName(jobName) then return false, 'Ugyldigt job.' end
  grade = tonumber(grade)
  if not grade or grade < 0 then return false, 'Ugyldig rang.' end
  salary = Utils.ensureNumber(salary, 0)

  local gradesT = esx.jobGradesTable
  MySQL.update.await(
    ('UPDATE %s SET %s = ? WHERE %s = ? AND %s = ?'):format(
      tableName(gradesT),
      col(esx.jobGradesColumns, 'salary'),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    ),
    { salary, jobName, grade }
  )
  return true
end

function DB.deleteGrade(jobName, grade)
  local esx = Config.ESX
  if not Utils.isValidName(jobName) then return false, 'Ugyldigt job.' end
  grade = tonumber(grade)
  if not grade or grade < 0 then return false, 'Ugyldig rang.' end

  local gradesT = esx.jobGradesTable
  MySQL.update.await(
    ('DELETE FROM %s WHERE %s = ? AND %s = ?'):format(
      tableName(gradesT),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    ),
    { jobName, grade }
  )
  return true
end

function DB.fetchGrades(jobName)
  local esx = Config.ESX
  local gradesT = esx.jobGradesTable
  return MySQL.query.await(
    ('SELECT %s AS grade, %s AS name, %s AS label, %s AS salary FROM %s WHERE %s = ? ORDER BY %s ASC'):format(
      col(esx.jobGradesColumns, 'grade'),
      col(esx.jobGradesColumns, 'name'),
      col(esx.jobGradesColumns, 'label'),
      col(esx.jobGradesColumns, 'salary'),
      tableName(gradesT),
      col(esx.jobGradesColumns, 'jobName'),
      col(esx.jobGradesColumns, 'grade')
    ),
    { jobName }
  ) or {}
end

-- Boss menu persistence/cache
local bossMenus = {}

function DB.ensureBossMenuTable()
  MySQL.query.await([[
    CREATE TABLE IF NOT EXISTS `nw_jobcreator_bossmenus` (
      `id` INT NOT NULL AUTO_INCREMENT,
      `label` VARCHAR(64) NOT NULL DEFAULT 'Boss-menu',
      `job` VARCHAR(32) NOT NULL,
      `min_grade` INT NOT NULL DEFAULT 0,
      `money_min_grade` INT NOT NULL DEFAULT 0,
      `employees_min_grade` INT NOT NULL DEFAULT 0,
      `ui` VARCHAR(16) NOT NULL DEFAULT 'ox_lib',
      `open_type` VARCHAR(16) NOT NULL DEFAULT 'text',
      `x` DOUBLE NOT NULL,
      `y` DOUBLE NOT NULL,
      `z` DOUBLE NOT NULL,
      `radius` DOUBLE NOT NULL DEFAULT 1.5,
      `icon` VARCHAR(64) NULL,
      `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (`id`),
      INDEX `job_idx` (`job`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
  ]])

  -- Lightweight migrations (for existing installs).
  local tableRaw = 'nw_jobcreator_bossmenus'
  local function ensureColumn(colName, ddl)
    local ok, has = pcall(function()
      return maybeHasColumn(tableRaw, colName)
    end)
    if ok and not has then
      MySQL.query.await('ALTER TABLE ' .. tableName(tableRaw) .. ' ADD COLUMN ' .. ddl)
    end
  end

  ensureColumn('money_min_grade', '`money_min_grade` INT NOT NULL DEFAULT 0')
  ensureColumn('employees_min_grade', '`employees_min_grade` INT NOT NULL DEFAULT 0')
end

function DB.loadBossMenus()
  DB.ensureBossMenuTable()
  bossMenus = MySQL.query.await('SELECT * FROM `nw_jobcreator_bossmenus` ORDER BY `id` ASC') or {}
  return bossMenus
end

function DB.getBossMenus()
  return bossMenus
end

function DB.createBossMenu(entry)
  DB.ensureBossMenuTable()
  local id = MySQL.insert.await([[
    INSERT INTO `nw_jobcreator_bossmenus`
      (`label`, `job`, `min_grade`, `money_min_grade`, `employees_min_grade`, `ui`, `open_type`, `x`, `y`, `z`, `radius`, `icon`)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  ]], {
    entry.label,
    entry.job,
    entry.min_grade,
    entry.money_min_grade,
    entry.employees_min_grade,
    entry.ui,
    entry.open_type,
    entry.x, entry.y, entry.z,
    entry.radius,
    entry.icon
  })
  return id
end

function DB.deleteBossMenu(id)
  DB.ensureBossMenuTable()
  MySQL.update.await('DELETE FROM `nw_jobcreator_bossmenus` WHERE `id` = ?', { id })
end

return DB
