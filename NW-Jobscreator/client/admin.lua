local UI = lib.require('shared.ui')
local Utils = lib.require('shared.utils')
local CoordPicker = lib.require('client.coordpicker')

local function openJobsMenu()
  CreateThread(function()
    local data = lib.callback.await('nw_jobscreator:cb:getJobsWithGrades', false)
    if not data then
      UI.notify('Kunne ikke hente jobs fra serveren.', 'error')
      return
    end

    local options = {
      {
        title = 'Opret job',
        description = 'Tilføj et nyt job i databasen',
        icon = 'fa-solid fa-plus',
        onSelect = function()
          local input = UI.input('Opret job', {
            { type = 'input', label = 'Job navn (lowercase_underscore)', required = true },
            { type = 'input', label = 'Job label (vises i UI)', required = true },
          })
          if not input then return end
          local name = Utils.trim(input[1] or '')
          local label = Utils.trim(input[2] or '')
          TriggerServerEvent('nw_jobscreator:server:createJob', name, label)
        end
      }
    }

    options[#options + 1] = {
      title = 'Boss-menuer',
      description = 'Opret/administrer boss-menu lokationer',
      icon = 'fa-solid fa-building',
      onSelect = function()
        CreateThread(function()
          local menus = lib.callback.await('nw_jobscreator:cb:getBossMenus', false) or {}

          local bossOpts = {
            {
              title = 'Opret boss-menu',
              icon = 'fa-solid fa-plus',
              onSelect = function()
                CreateThread(function()
                  local jobOptions = {}
                  for _, job in ipairs(data.jobs) do
                    jobOptions[#jobOptions + 1] = {
                      label = string.format('%s (%s)', job.label, job.name),
                      value = job.name
                    }
                  end

                  local inp = UI.input('Opret boss-menu', {
                    { type = 'input', label = 'Label', required = true, default = 'Boss-menu' },
                    { type = 'select', label = 'Job', required = true, options = jobOptions },
                    { type = 'number', label = 'Min. rang (åbn)', required = true, default = 0 },
                    { type = 'number', label = 'Min. rang (penge)', required = true, default = 0 },
                    { type = 'number', label = 'Min. rang (ansatte)', required = true, default = 0 },
                    { type = 'select', label = 'UI', required = true, options = {
                      { label = 'ox_lib', value = 'ox_lib' },
                      { label = 'lation_ui', value = 'lation_ui' }
                    } },
                    { type = 'select', label = 'Åbningstype', required = true, options = {
                      { label = 'Tekst (E)', value = 'text' },
                      { label = 'ox_target', value = 'target' }
                    } },
                    { type = 'number', label = 'Radius', required = true, default = Config.BossMenus.defaultZoneRadius or 1.5 },
                    { type = 'input', label = 'Ikon (ox_target)', required = false, placeholder = 'fa-solid fa-briefcase' }
                  })
                  if not inp then return end

                  local icon = Utils.trim(inp[9] or '')
                  if icon == '' then icon = nil end

                  local coords = CoordPicker.pick3D(inp[6])
                  if not coords then
                    UI.notify('Annulleret.', 'error')
                    return
                  end

                  TriggerServerEvent('nw_jobscreator:server:createBossMenu', {
                    label = Utils.trim(inp[1] or 'Boss-menu'),
                    job = inp[2],
                    min_grade = tonumber(inp[3]) or 0,
                    money_min_grade = tonumber(inp[4]) or 0,
                    employees_min_grade = tonumber(inp[5]) or 0,
                    ui = inp[6],
                    open_type = inp[7],
                    radius = tonumber(inp[8]) or (Config.BossMenus.defaultZoneRadius or 1.5),
                    icon = icon,
                    x = coords.x,
                    y = coords.y,
                    z = coords.z
                  })
                end)
              end
            }
          }

          for _, m in ipairs(menus) do
            bossOpts[#bossOpts + 1] = {
              title = string.format('#%s %s', m.id, m.label or 'Boss-menu'),
              description = string.format('%s | %s | %s (åbn>=%s penge>=%s ansatte>=%s)', m.job, m.open_type, m.ui, m.min_grade, m.money_min_grade or 0, m.employees_min_grade or 0),
              icon = 'fa-solid fa-briefcase',
              onSelect = function()
                local alert = lib.alertDialog({
                  header = 'Slet boss-menu?',
                  content = ('Slet boss-menu id %s?'):format(m.id),
                  centered = true,
                  cancel = true
                })
                if alert == 'confirm' then
                  TriggerServerEvent('nw_jobscreator:server:deleteBossMenu', m.id)
                end
              end
            }
          end

          UI.showContext('ox_lib', 'nw_jobscreator_bossmenus', 'Boss-menuer', bossOpts)
        end)
      end
    }

    for _, job in ipairs(data.jobs) do
      options[#options + 1] = {
        title = string.format('%s (%s)', job.label, job.name),
        description = 'Administrer rang / rediger label / slet',
        icon = 'fa-solid fa-briefcase',
        onSelect = function()
          local jobName = job.name
          local jobLabel = job.label

          UI.showContext('ox_lib', 'nw_jobscreator_job_' .. jobName, 'Job: ' .. jobLabel, {
            {
              title = 'Rediger job label',
              icon = 'fa-solid fa-pen',
              onSelect = function()
                local inp = UI.input('Rediger job label', {
                  { type = 'input', label = 'Ny label', required = true, default = jobLabel }
                })
                if not inp then return end
                TriggerServerEvent('nw_jobscreator:server:updateJobLabel', jobName, Utils.trim(inp[1] or ''))
              end
            },
            {
              title = 'Administrer rang',
              icon = 'fa-solid fa-users',
              onSelect = function()
                local grades = data.gradesByJob[jobName] or {}
                local gOpts = {
                  {
                    title = 'Opret rang',
                    icon = 'fa-solid fa-plus',
                    onSelect = function()
                      local inp = UI.input('Opret rang', {
                        { type = 'number', label = 'Rang nummer (0+)', required = true },
                        { type = 'input', label = 'Rang navn (lowercase_underscore)', required = true },
                        { type = 'input', label = 'Rang label', required = true },
                        { type = 'number', label = 'Løn', required = true }
                      })
                      if not inp then return end
                      TriggerServerEvent('nw_jobscreator:server:createGrade', jobName, tonumber(inp[1]), Utils.trim(inp[2] or ''), Utils.trim(inp[3] or ''), tonumber(inp[4]))
                    end
                  }
                }
                for _, grade in ipairs(grades) do
                  gOpts[#gOpts + 1] = {
                    title = string.format('[%d] %s (%s)', grade.grade, grade.label, grade.name),
                    description = ('Løn: %s'):format(grade.salary),
                    icon = 'fa-solid fa-id-badge',
                    onSelect = function()
                      UI.showContext('ox_lib', ('nw_jobscreator_grade_%s_%s'):format(jobName, grade.grade), ('Rang %d'):format(grade.grade), {
                        {
                          title = 'Rediger',
                          icon = 'fa-solid fa-pen',
                          onSelect = function()
                            local inp = UI.input('Rediger rang', {
                              { type = 'input', label = 'Label', required = true, default = grade.label },
                              { type = 'number', label = 'Løn', required = true, default = grade.salary },
                            })
                            if not inp then return end
                            TriggerServerEvent('nw_jobscreator:server:updateGrade', jobName, grade.grade, Utils.trim(inp[1] or ''), tonumber(inp[2]))
                          end
                        },
                        {
                          title = 'Slet',
                          icon = 'fa-solid fa-trash',
                          onSelect = function()
                            local alert = lib.alertDialog({
                              header = 'Slet rang?',
                              content = ('Slet rang %d fra %s?'):format(grade.grade, jobName),
                              centered = true,
                              cancel = true
                            })
                            if alert == 'confirm' then
                              TriggerServerEvent('nw_jobscreator:server:deleteGrade', jobName, grade.grade)
                            end
                          end
                        }
                      })
                    end
                  }
                end
                UI.showContext('ox_lib', 'nw_jobscreator_grades_' .. jobName, 'Rang: ' .. jobLabel, gOpts)
              end
            },
            {
              title = 'Slet job',
              description = 'Sletter job og alle rang (DB)',
              icon = 'fa-solid fa-trash',
              onSelect = function()
                local alert = lib.alertDialog({
                  header = 'Slet job?',
                  content = ('Dette sletter `%s` og alle rang.'):format(jobName),
                  centered = true,
                  cancel = true
                })
                if alert == 'confirm' then
                  TriggerServerEvent('nw_jobscreator:server:deleteJob', jobName)
                end
              end
            }
          })
        end
      }
    end

    UI.showContext('ox_lib', 'nw_jobscreator_jobs', 'Jobskaber', options)
  end)
end

RegisterCommand('jobscreator', function()
  CreateThread(function()
    local isAdmin = lib.callback.await('nw_jobscreator:cb:isAdmin', false)
    if not isAdmin then
      UI.notify('Ingen adgang.', 'error')
      return
    end
    openJobsMenu()
  end)
end, false)
