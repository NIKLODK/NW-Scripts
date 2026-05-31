local DB = lib.require('server.db')
local Auth = lib.require('server.auth')

lib.callback.register('nw_jobscreator:cb:isAdmin', function(src)
  return Auth.isAdmin(src)
end)

lib.callback.register('nw_jobscreator:cb:getJobsWithGrades', function(src)
  if not Auth.isAdmin(src) then return nil end
  local jobs, grades = DB.fetchJobsWithGrades()
  local gradesByJob = {}
  for _, g in ipairs(grades) do
    gradesByJob[g.job_name] = gradesByJob[g.job_name] or {}
    gradesByJob[g.job_name][#gradesByJob[g.job_name] + 1] = g
  end
  return { jobs = jobs, gradesByJob = gradesByJob }
end)

RegisterNetEvent('nw_jobscreator:server:createJob', function(name, label)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.createJob(name, label)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Kunne ikke oprette job.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Job oprettet.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:updateJobLabel', function(name, newLabel)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.updateJobLabel(name, newLabel)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Job label opdateret.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:deleteJob', function(name)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.deleteJob(name)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Job slettet.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:createGrade', function(jobName, grade, gName, gLabel, salary)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.createGrade(jobName, tonumber(grade), gName, gLabel, tonumber(salary))
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Rang oprettet.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:updateGrade', function(jobName, grade, newLabel, newSalary)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.updateGrade(jobName, grade, newLabel, newSalary)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Rang opdateret.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)

RegisterNetEvent('nw_jobscreator:server:deleteGrade', function(jobName, grade)
  local src = source
  if not Auth.isAdmin(src) then return end
  local ok, err = DB.deleteGrade(jobName, grade)
  if not ok then
    TriggerClientEvent('nw_jobscreator:client:notify', src, err or 'Fejl.', 'error')
    return
  end
  TriggerClientEvent('nw_jobscreator:client:notify', src, 'Rang slettet.', 'success')
  TriggerEvent('nw_jobscreator:server:refreshCache')
end)
