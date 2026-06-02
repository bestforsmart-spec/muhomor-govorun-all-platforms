local function alert(text)
  hs.alert.closeAll()
  hs.alert.show(text, 1.2)
end

pcall(function()
  hs.ipc.cliInstall()
  hs.ipc.cliSaveHistory(false)
  hs.ipc.localPort()
end)

local runtimeRoot = os.getenv('MUHOMOR_RUNTIME_ROOT') or (os.getenv('HOME') .. '/.muhomor-govorun/local-ai-tools')
local smartVoiceCommand = runtimeRoot .. '/bin/smart_voice.sh'
local speakCommand = runtimeRoot .. '/bin/speak_file.sh'
local summaryCommand = runtimeRoot .. '/bin/summarize_and_speak.sh'
local searchExplainCommand = runtimeRoot .. '/bin/search_explain_and_speak.sh'
local singleRunCommand = runtimeRoot .. '/bin/voice_single_run.sh'
local connectionCheckCommand = runtimeRoot .. '/bin/enterprise_check_connections.sh'
local voiceStatusFile = '/tmp/muhomor_govorun_status.txt'
local voiceHistoryFile = '/tmp/muhomor_govorun_history.txt'
local voiceStopFile = '/tmp/muhomor_govorun_stop.flag'
local voiceLockDir = '/tmp/muhomor_govorun_voice.lock'
local voiceSettingsFile = runtimeRoot .. '/config/voice_extension_settings.json'
local saluteEnvFile = runtimeRoot .. '/config/salute_speech.env'
local gigachatEnvFile = runtimeRoot .. '/config/gigachat.env'
local braveEnvFile = runtimeRoot .. '/config/brave_search.env'
local elevenLabsEnvFile = runtimeRoot .. '/config/elevenlabs.env'
local configDir = runtimeRoot .. '/config'
local brandName = 'Мухомор - Говорун'
local brandVersion = 'v1.2 simple'
local voiceStatusBar = hs.menubar.new()
local voiceStatusTimer = nil
local voiceStatusStartedAt = nil
local voiceHistoryChooser = nil
local clearVoiceStatus
local cleanupFile
local setVoiceStatus
local stopVoiceStatusPolling
local voiceErrorResetTimer = nil
local voiceTaskRunning = false
local sayVoiceCache = nil

local function stopVoiceErrorResetTimer()
  if voiceErrorResetTimer then
    voiceErrorResetTimer:stop()
    voiceErrorResetTimer = nil
  end
end

local function statusLamp(text)
  local normalized = (text or ''):lower()
  if normalized == 'готов' or normalized:find('озвучиваю', 1, true) or normalized:find('воспроизв', 1, true) then
    return '🟢'
  end
  if normalized:find('ошиб', 1, true) or normalized:find('не сработал', 1, true) or normalized:find('не удалось', 1, true) then
    return '🔴'
  end
  return '🟡'
end

local function statusEmoji(text)
  local normalized = (text or ''):lower()
  if normalized == 'готов' then
    return '✨'
  end
  if normalized:find('ошиб', 1, true) or normalized:find('не сработал', 1, true) or normalized:find('не удалось', 1, true) then
    return '⚠️'
  end
  if normalized:find('ищу в brave', 1, true) then
    return '🔎'
  end
  if normalized:find('собираю результат', 1, true) or normalized:find('собираю top', 1, true) then
    return '📚'
  end
  if normalized:find('отправляю в openai', 1, true) or normalized:find('отправляю в gpt-5.5', 1, true) then
    return '🧠'
  end
  if normalized:find('отправляю в gigachat', 1, true) then
    return '🤖'
  end
  if normalized:find('генерирую аудио', 1, true) then
    return '🎧'
  end
  if normalized:find('озвучиваю', 1, true) or normalized:find('воспроизв', 1, true) then
    return '🗣️'
  end
  if normalized:find('нормализую', 1, true) or normalized:find('готовлю текст', 1, true) then
    return '📝'
  end
  if normalized:find('делаю summary', 1, true) or normalized:find('анализирую текст', 1, true) or normalized:find('оцениваю запрос', 1, true) then
    return '🧩'
  end
  if normalized:find('готовлю поиск', 1, true) or normalized:find('готовлю озвучку', 1, true) then
    return '🚀'
  end
  if normalized:find('перехожу на быстрый голос', 1, true) then
    return '⚡'
  end
  return '💬'
end

local function stopVoice(showAlert)
  local handle = io.open(voiceStopFile, 'w')
  if handle then
    handle:write('stop\n')
    handle:close()
  end
  hs.task.new('/bin/zsh', nil, {
    '-lc',
    'killall say >/dev/null 2>&1 || true; killall afplay >/dev/null 2>&1 || true; pkill -f salute_tts_file.sh >/dev/null 2>&1 || true; pkill -f local_fast_tts_file.sh >/dev/null 2>&1 || true; pkill -f elevenlabs_tts_file.sh >/dev/null 2>&1 || true; pkill -f elevenlabs_tts_file.py >/dev/null 2>&1 || true; pkill -f speak_file.sh >/dev/null 2>&1 || true; pkill -f speak_chunks_file.sh >/dev/null 2>&1 || true; pkill -f smart_voice.sh >/dev/null 2>&1 || true; pkill -f summarize_and_speak.sh >/dev/null 2>&1 || true; pkill -f search_explain_and_speak.sh >/dev/null 2>&1 || true; pkill -f search_explain_for_voice.sh >/dev/null 2>&1 || true; pkill -f voice_single_run.sh >/dev/null 2>&1 || true; pkill -f curl.*ngw.devices.sberbank.ru >/dev/null 2>&1 || true; pkill -f curl.*api.search.brave.com >/dev/null 2>&1 || true; pkill -f curl.*api.elevenlabs.io >/dev/null 2>&1 || true; rm -rf ' .. voiceLockDir
  }):start()
  voiceTaskRunning = false
  stopVoiceStatusPolling()
  stopVoiceErrorResetTimer()
  cleanupFile(voiceStatusFile)
  voiceStatusStartedAt = nil
  setVoiceStatus('Остановлено')
  if showAlert ~= false then
    hs.timer.doAfter(0.8, function()
      if not voiceTaskRunning then
        clearVoiceStatus()
      end
    end)
  end
end

local function restartVoiceProcess()
  clearVoiceStatus()
  hs.reload()
end

cleanupFile = function(path)
  if path and path ~= '' then
    os.remove(path)
  end
end

local function fileExists(path)
  return type(path) == 'string' and path ~= '' and hs.fs.attributes(path) ~= nil
end

local function ensureSettingsDir()
  hs.fs.mkdir(runtimeRoot .. '/config')
end

local function defaultSettings()
  return {
    tts_backend = 'local_fast',
    local_tts_voice = 'Milena',
    voice_label = 'Локальный быстрый голос',
    summary_backend = 'gigachat_api',
    search_explain_backend = 'gigachat_api',
    summary_style = 'balanced',
    voice_style = 'local_fast',
  }
end

local function loadSettings()
  ensureSettingsDir()
  local defaults = defaultSettings()
  local handle = io.open(voiceSettingsFile, 'r')
  if not handle then
    return defaults
  end
  local content = handle:read('*a')
  handle:close()
  local ok, parsed = pcall(hs.json.decode, content)
  if not ok or type(parsed) ~= 'table' then
    return defaults
  end
  if type(parsed.tts_backend) ~= 'string' then
    parsed.tts_backend = defaults.tts_backend
  end
  if parsed.tts_backend == 'reels_tts' or parsed.tts_backend == 'reels_maker' or parsed.tts_backend == 'premium_reels' then
    parsed.tts_backend = defaults.tts_backend
    parsed.voice_label = defaults.voice_label
    parsed.voice_style = defaults.voice_style
  end
  if parsed.tts_backend ~= 'local_fast' and parsed.tts_backend ~= 'salute_tts' and parsed.tts_backend ~= 'elevenlabs_tts' then
    parsed.tts_backend = defaults.tts_backend
  end
  if type(parsed.local_tts_voice) ~= 'string' then
    parsed.local_tts_voice = parsed.reels_tts_say_voice or defaults.local_tts_voice
  end
  if type(parsed.voice_label) ~= 'string' then
    parsed.voice_label = defaults.voice_label
  end
  if type(parsed.summary_backend) ~= 'string' then
    parsed.summary_backend = defaults.summary_backend
  end
  if type(parsed.search_explain_backend) ~= 'string' then
    parsed.search_explain_backend = defaults.search_explain_backend
  end
  if type(parsed.summary_style) ~= 'string' then
    parsed.summary_style = defaults.summary_style
  end
  if type(parsed.voice_style) ~= 'string' then
    parsed.voice_style = defaults.voice_style
  end
  return parsed
end

local function saveSettings(settings)
  ensureSettingsDir()
  local encoded = hs.json.encode(settings, true)
  local handle = io.open(voiceSettingsFile, 'w')
  if not handle then
    alert('Не удалось сохранить настройки')
    return false
  end
  handle:write(encoded)
  handle:close()
  return true
end

local function ensureConfigFile(path, content)
  ensureSettingsDir()
  local handle = io.open(path, 'r')
  if handle then
    handle:close()
    return
  end
  handle = io.open(path, 'w')
  if handle then
    handle:write(content)
    handle:close()
  end
end

local function readEnvFile(path)
  local values = {}
  local handle = io.open(path, 'r')
  if not handle then
    return values
  end
  for line in handle:lines() do
    local key, value = line:match('^([A-Z0-9_]+)=(.*)$')
    if key then
      values[key] = value
    end
  end
  handle:close()
  return values
end

local function writeEnvFile(path, orderedKeys, values)
  ensureSettingsDir()
  local handle = io.open(path, 'w')
  if not handle then
    alert('Не удалось сохранить конфиг')
    return false
  end
  for _, key in ipairs(orderedKeys) do
    handle:write(string.format('%s=%s\n', key, values[key] or ''))
  end
  handle:close()
  return true
end

local function availableSayVoices()
  if sayVoiceCache then
    return sayVoiceCache
  end
  sayVoiceCache = {}
  local output = hs.execute("/usr/bin/say -v '?' 2>/dev/null", true) or ''
  for line in output:gmatch('[^\n]+') do
    local voice = line:match('^(.-)%s+[%a][%a]_[%w]+%s+#')
    if voice and voice ~= '' then
      sayVoiceCache[voice] = true
    end
  end
  return sayVoiceCache
end

local function sayVoiceExists(voice)
  local voices = availableSayVoices()
  return voices[voice] == true
end

local function escapeAppleScript(text)
  local escaped = text or ''
  escaped = escaped:gsub('\\', '\\\\')
  escaped = escaped:gsub('"', '\\"')
  escaped = escaped:gsub('\n', '\\n')
  return escaped
end

local function promptDialog(title, message, defaultValue, hidden)
  local script = string.format([[
tell application "System Events"
  activate
  set dialogResult to display dialog "%s" with title "%s" default answer "%s" %s buttons {"Отмена", "Сохранить"} default button "Сохранить"
  text returned of dialogResult
end tell
]], escapeAppleScript(message), escapeAppleScript(title), escapeAppleScript(defaultValue or ''), hidden and 'with hidden answer' or '')
  local ok, result = hs.osascript.applescript(script)
  if ok then
    return result
  end
  return nil
end

local function showInfoDialog(title, message)
  local script = string.format([[
tell application "System Events"
  activate
  display dialog "%s" with title "%s" buttons {"OK"} default button "OK"
end tell
]], escapeAppleScript(message), escapeAppleScript(title))
  hs.osascript.applescript(script)
end

local function configureSaluteToken()
  ensureConfigFile(saluteEnvFile, 'SALUTE_AUTH_KEY=\nSALUTE_SCOPE=SALUTE_SPEECH_PERS\nSALUTE_VOICE=Ost_24000\nSALUTE_FORMAT=wav16\nSALUTE_CURL_INSECURE=0\nSALUTE_CA_BUNDLE=' .. runtimeRoot .. '/config/sber-trusted-chain.pem\n')
  local current = readEnvFile(saluteEnvFile)
  local value = promptDialog(brandName, 'Вставьте токен SaluteSpeech API.\n\nПодсказка: токен будет сохранён локально только на этом Mac.', current.SALUTE_AUTH_KEY or '', true)
  if value == nil then
    return
  end
  current.SALUTE_AUTH_KEY = value
  current.SALUTE_SCOPE = current.SALUTE_SCOPE or 'SALUTE_SPEECH_PERS'
  current.SALUTE_VOICE = current.SALUTE_VOICE or 'Ost_24000'
  current.SALUTE_FORMAT = current.SALUTE_FORMAT or 'wav16'
  current.SALUTE_CURL_INSECURE = '0'
  current.SALUTE_CA_BUNDLE = current.SALUTE_CA_BUNDLE or (runtimeRoot .. '/config/sber-trusted-chain.pem')
  if writeEnvFile(saluteEnvFile, {'SALUTE_AUTH_KEY', 'SALUTE_SCOPE', 'SALUTE_VOICE', 'SALUTE_FORMAT', 'SALUTE_CURL_INSECURE', 'SALUTE_CA_BUNDLE'}, current) then
    alert('SaluteSpeech API сохранён')
  end
end

local function ensureSaluteConfig()
  ensureConfigFile(saluteEnvFile, 'SALUTE_AUTH_KEY=\nSALUTE_SCOPE=SALUTE_SPEECH_PERS\nSALUTE_VOICE=Ost_24000\nSALUTE_FORMAT=wav16\nSALUTE_CURL_INSECURE=0\nSALUTE_CA_BUNDLE=' .. runtimeRoot .. '/config/sber-trusted-chain.pem\n')
end

local function currentSaluteVoice()
  ensureSaluteConfig()
  local current = readEnvFile(saluteEnvFile)
  return current.SALUTE_VOICE or 'Ost_24000'
end

local function saveSaluteVoice(voiceCode)
  ensureSaluteConfig()
  local current = readEnvFile(saluteEnvFile)
  current.SALUTE_AUTH_KEY = current.SALUTE_AUTH_KEY or ''
  current.SALUTE_SCOPE = current.SALUTE_SCOPE or 'SALUTE_SPEECH_PERS'
  current.SALUTE_VOICE = voiceCode
  current.SALUTE_FORMAT = current.SALUTE_FORMAT or 'wav16'
  current.SALUTE_CURL_INSECURE = '0'
  current.SALUTE_CA_BUNDLE = runtimeRoot .. '/config/sber-trusted-chain.pem'
  return writeEnvFile(saluteEnvFile, {'SALUTE_AUTH_KEY', 'SALUTE_SCOPE', 'SALUTE_VOICE', 'SALUTE_FORMAT', 'SALUTE_CURL_INSECURE', 'SALUTE_CA_BUNDLE'}, current)
end

local function selectSaluteVoice(voiceCode)
  if not saveSaluteVoice(voiceCode) then
    return false
  end
  local settings = loadSettings()
  settings.tts_backend = 'salute_tts'
  settings.voice_style = 'cloud_fast'
  settings.voice_label = 'SaluteSpeech быстрый облачный'
  return saveSettings(settings)
end

local function selectLocalFastVoice()
  local settings = loadSettings()
  settings.tts_backend = 'local_fast'
  settings.local_tts_voice = settings.local_tts_voice or 'Milena'
  settings.voice_style = 'local_fast'
  settings.voice_label = 'Локальный быстрый голос'
  return saveSettings(settings)
end

local function selectElevenLabsVoice()
  local settings = loadSettings()
  settings.tts_backend = 'elevenlabs_tts'
  settings.voice_style = 'beautiful_cloud'
  settings.voice_label = 'ElevenLabs красивый голос'
  return saveSettings(settings)
end

local function configureGigaChatToken()
  ensureConfigFile(gigachatEnvFile, 'GIGACHAT_AUTH_KEY=\nGIGACHAT_MODEL=GigaChat\nGIGACHAT_EXPLAIN_MODEL=GigaChat\nGIGACHAT_SCOPE=GIGACHAT_API_PERS\nGIGACHAT_CURL_INSECURE=0\nGIGACHAT_CA_BUNDLE=' .. runtimeRoot .. '/config/sber-trusted-chain.pem\n')
  local current = readEnvFile(gigachatEnvFile)
  local value = promptDialog(brandName, 'Вставьте ключ GigaChat API.\n\nПодсказка: ключ будет сохранён локально только на этом Mac.', current.GIGACHAT_AUTH_KEY or '', true)
  if value == nil then
    return
  end
  current.GIGACHAT_AUTH_KEY = value
  current.GIGACHAT_MODEL = current.GIGACHAT_MODEL or 'GigaChat'
  current.GIGACHAT_EXPLAIN_MODEL = current.GIGACHAT_EXPLAIN_MODEL or 'GigaChat'
  current.GIGACHAT_SCOPE = current.GIGACHAT_SCOPE or 'GIGACHAT_API_PERS'
  current.GIGACHAT_CURL_INSECURE = '0'
  current.GIGACHAT_CA_BUNDLE = current.GIGACHAT_CA_BUNDLE or (runtimeRoot .. '/config/sber-trusted-chain.pem')
  if writeEnvFile(gigachatEnvFile, {'GIGACHAT_AUTH_KEY', 'GIGACHAT_MODEL', 'GIGACHAT_EXPLAIN_MODEL', 'GIGACHAT_SCOPE', 'GIGACHAT_CURL_INSECURE', 'GIGACHAT_CA_BUNDLE'}, current) then
    alert('GigaChat API сохранён')
  end
end

local function configureBraveToken()
  ensureConfigFile(braveEnvFile, 'BRAVE_SEARCH_API_KEY=\nBRAVE_SEARCH_COUNT=8\n')
  local current = readEnvFile(braveEnvFile)
  local value = promptDialog(brandName, 'Вставьте Brave Search API key.\n\nПодсказка: он нужен для команды Brave поиск + GPT-5.5 голосом.', current.BRAVE_SEARCH_API_KEY or '', true)
  if value == nil then
    return
  end
  current.BRAVE_SEARCH_API_KEY = value
  current.BRAVE_SEARCH_COUNT = current.BRAVE_SEARCH_COUNT or '8'
  if writeEnvFile(braveEnvFile, {'BRAVE_SEARCH_API_KEY', 'BRAVE_SEARCH_COUNT'}, current) then
    alert('Brave Search API сохранён')
  end
end

local function configureElevenLabsKey()
  ensureConfigFile(elevenLabsEnvFile, 'ELEVENLABS_API_KEY=\nELEVENLABS_VOICE_ID=JBFqnCBsd6RMkjVDRZzb\nELEVENLABS_MODEL_ID=eleven_multilingual_v2\nELEVENLABS_OUTPUT_FORMAT=mp3_44100_128\nELEVENLABS_STABILITY=0.48\nELEVENLABS_SIMILARITY_BOOST=0.78\nELEVENLABS_STYLE=0.18\n')
  local current = readEnvFile(elevenLabsEnvFile)
  local value = promptDialog(brandName, 'Вставьте ElevenLabs API key.\n\nПодсказка: он нужен для красивого облачного голоса и будет сохранён локально только на этом Mac.', current.ELEVENLABS_API_KEY or '', true)
  if value == nil then
    return
  end
  current.ELEVENLABS_API_KEY = value
  current.ELEVENLABS_VOICE_ID = current.ELEVENLABS_VOICE_ID or 'JBFqnCBsd6RMkjVDRZzb'
  current.ELEVENLABS_MODEL_ID = current.ELEVENLABS_MODEL_ID or 'eleven_multilingual_v2'
  current.ELEVENLABS_OUTPUT_FORMAT = current.ELEVENLABS_OUTPUT_FORMAT or 'mp3_44100_128'
  current.ELEVENLABS_STABILITY = current.ELEVENLABS_STABILITY or '0.48'
  current.ELEVENLABS_SIMILARITY_BOOST = current.ELEVENLABS_SIMILARITY_BOOST or '0.78'
  current.ELEVENLABS_STYLE = current.ELEVENLABS_STYLE or '0.18'
  if writeEnvFile(elevenLabsEnvFile, {'ELEVENLABS_API_KEY', 'ELEVENLABS_VOICE_ID', 'ELEVENLABS_MODEL_ID', 'ELEVENLABS_OUTPUT_FORMAT', 'ELEVENLABS_STABILITY', 'ELEVENLABS_SIMILARITY_BOOST', 'ELEVENLABS_STYLE'}, current) then
    selectElevenLabsVoice()
    alert('ElevenLabs API сохранён')
  end
end

local function runConnectionCheck()
  hs.task.new('/bin/zsh', function(exitCode, stdOut, stdErr)
    local report = ((stdOut or '') .. (stdErr or '')):gsub('%s+$', '')
    if report == '' then
      report = 'Диагностика не вернула данных.'
    end
    showInfoDialog(brandName .. ' · Диагностика', report)
  end, {'-lc', connectionCheckCommand}):start()
end

local function openConfigFolder()
  hs.execute(string.format([[open %q]], configDir), false)
end

local function resetEnterpriseSettings()
  saveSettings(defaultSettings())
  alert('Настройки сброшены')
end

setVoiceStatus = function(text)
  local display = text
  if voiceStatusStartedAt and text == 'Генерирую аудио' then
    local elapsed = math.max(0, math.floor(hs.timer.secondsSinceEpoch() - voiceStatusStartedAt))
    display = string.format('%s %ds', text, elapsed)
  end
  if voiceStatusBar then
    voiceStatusBar:setTitle(brandName .. ' · ' .. statusEmoji(text) .. ' ' .. display .. ' ' .. statusLamp(text))
  end
end

local function showErrorStatus(text)
  stopVoiceStatusPolling()
  stopVoiceErrorResetTimer()
  voiceStatusStartedAt = nil
  setVoiceStatus(text)
  voiceErrorResetTimer = hs.timer.doAfter(2.4, function()
    voiceErrorResetTimer = nil
    clearVoiceStatus()
  end)
end

stopVoiceStatusPolling = function()
  if voiceStatusTimer then
    voiceStatusTimer:stop()
    voiceStatusTimer = nil
  end
end

clearVoiceStatus = function()
  stopVoiceStatusPolling()
  stopVoiceErrorResetTimer()
  cleanupFile(voiceStatusFile)
  voiceStatusStartedAt = nil
  voiceTaskRunning = false
  setVoiceStatus('готов')
end

local function readVoiceHistoryItems()
  local handle = io.open(voiceHistoryFile, 'r')
  if not handle then
    return {}
  end

  local rows = {}
  for line in handle:lines() do
    local ok, decoded = pcall(hs.json.decode, line)
    if ok and type(decoded) == 'table' and type(decoded.text) == 'string' and decoded.text ~= '' then
      local ts = decoded.timestamp or ''
      local mode = decoded.mode or 'Озвучка'
      local chars = tonumber(decoded.chars) or utf8.len(decoded.text) or #decoded.text
      local timeText = ts:match('%d%d:%d%d:%d%d') or ts
      local preview = decoded.text:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
      if #preview > 110 then
        preview = preview:sub(1, 107) .. '...'
      end
      table.insert(rows, 1, {
        text = string.format('[%s] %s', mode, preview),
        subText = string.format('%s · %d симв', timeText, chars),
        fullText = decoded.text,
      })
    else
      local timeText, message = line:match('^(%d%d:%d%d:%d%d)%s*\t%s*(.*)$')
      if timeText and message and message ~= '' then
        local preview = message:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
        if #preview > 110 then
          preview = preview:sub(1, 107) .. '...'
        end
        table.insert(rows, 1, {
          text = '[Архив] ' .. preview,
          subText = string.format('%s · %d симв', timeText, #message),
          fullText = message,
        })
      end
    end
  end
  handle:close()

  local items = {}
  local limit = math.min(#rows, 40)
  for i = 1, limit do
    local row = rows[i]
    table.insert(items, {
      text = row.text,
      subText = row.subText,
      fullText = row.fullText,
      uuid = tostring(i),
    })
  end
  return items
end

local function showVoiceHistory()
  if not voiceHistoryChooser then
    voiceHistoryChooser = hs.chooser.new(function(choice)
      if not choice then
        return
      end
      hs.pasteboard.setContents(choice.fullText or choice.text or '')
      alert('Полный текст скопирован в буфер')
    end)
    voiceHistoryChooser:searchSubText(true)
    voiceHistoryChooser:rows(14)
    voiceHistoryChooser:width(52)
  end

  local items = readVoiceHistoryItems()
  if #items == 0 then
    alert('История озвучки пока пуста')
    return
  end

  voiceHistoryChooser:choices(items)
  voiceHistoryChooser:placeholderText('История ответов и озвучки')
  voiceHistoryChooser:show()
end

local function startVoiceStatusPolling(initialText)
  cleanupFile(voiceStatusFile)
  voiceStatusStartedAt = hs.timer.secondsSinceEpoch()
  setVoiceStatus(initialText)
  stopVoiceStatusPolling()
  voiceStatusTimer = hs.timer.doEvery(0.25, function()
    local handle = io.open(voiceStatusFile, 'r')
    if not handle then
      return
    end
    local text = handle:read('*a')
    handle:close()
    text = (text or ''):gsub('%s+$', '')
    if text ~= '' then
      if text ~= 'Генерирую аудио' then
        voiceStatusStartedAt = hs.timer.secondsSinceEpoch()
      elseif not voiceStatusStartedAt then
        voiceStatusStartedAt = hs.timer.secondsSinceEpoch()
      end
      setVoiceStatus(text)
    end
  end)
end

local function restoreClipboard(original)
  if original == nil then
    hs.pasteboard.clearContents()
    return
  end
  hs.pasteboard.setContents(original)
end

local function runTask(taskPath, args, successText)
  cleanupFile(voiceStopFile)
  voiceTaskRunning = true
  local env = {
    VOICE_STATUS_FILE = voiceStatusFile,
    VOICE_HISTORY_FILE = voiceHistoryFile,
    VOICE_STOP_FILE = voiceStopFile,
  }
  local wrappedArgs = {taskPath}
  if args then
    for _, arg in ipairs(args) do
      table.insert(wrappedArgs, arg)
    end
  end
  local task = hs.task.new(singleRunCommand, function(exitCode, stdOut, stdErr)
    local tmpFile = args and args[1]
    if tmpFile and tmpFile ~= '' then
      cleanupFile(tmpFile)
    end
    if exitCode == 0 then
      voiceTaskRunning = false
      clearVoiceStatus()
      alert(successText)
      return
    end
    local out = (stdOut or '') .. (stdErr or '')
    if out:find('NO_READABLE_TEXT') then
      showErrorStatus('Ошибка')
      alert('Не удалось получить читаемый текст')
    elseif out:find('NO_SUMMARY') then
      showErrorStatus('Ошибка')
      alert('Не удалось сделать краткую суть')
    elseif out:find('SUMMARY_CODEX_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('OpenAI summary отвечает слишком долго')
    elseif out:find('SUMMARY_CODEX_FAILED') then
      showErrorStatus('Ошибка')
      alert('Codex summary не сработал')
    elseif out:find('SUMMARY_GIGACHAT_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('GigaChat summary отвечает слишком долго')
    elseif out:find('SUMMARY_GIGACHAT_') then
      showErrorStatus('Ошибка')
      alert('GigaChat summary не сработал')
    elseif out:find('BRAVE_ENV_MISSING') or out:find('BRAVE_AUTH_MISSING') then
      showErrorStatus('Ошибка')
      alert('Сначала подключите Brave Search API в настройках')
    elseif out:find('BRAVE_SEARCH_FAILED') then
      showErrorStatus('Ошибка')
      alert('Brave Search не сработал')
    elseif out:find('BRAVE_SEARCH_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('Brave Search отвечает слишком долго')
    elseif out:find('SEARCH_EXPLAIN_CODEX_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('OpenAI пояснение отвечает слишком долго')
    elseif out:find('SEARCH_EXPLAIN_CODEX_FAILED') then
      showErrorStatus('Ошибка')
      alert('OpenAI объяснение не сработало')
    elseif out:find('SEARCH_EXPLAIN_GIGACHAT_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('GigaChat пояснение отвечает слишком долго')
    elseif out:find('EXPLAIN_GIGACHAT_TIMEOUT') then
      showErrorStatus('Ошибка')
      alert('GigaChat объяснение отвечает слишком долго')
    elseif out:find('EXPLAIN_GIGACHAT_') then
      showErrorStatus('Ошибка')
      alert('GigaChat объяснение не сработало')
    elseif out:find('SEARCH_EXPLAIN_GIGACHAT_') then
      showErrorStatus('Ошибка')
      alert('GigaChat пояснение не сработало')
    elseif out:find('VOICE_ALREADY_RUNNING') then
      showErrorStatus('Занято')
      alert('Мухомор уже говорит или обрабатывает предыдущий запрос')
    elseif out:find('SALUTE_TTS_') then
      showErrorStatus('Ошибка')
      alert('SaluteSpeech не смог сгенерировать или воспроизвести аудио')
    elseif out:find('ELEVENLABS_TTS_') then
      showErrorStatus('Ошибка')
      alert('ElevenLabs не смог сгенерировать или воспроизвести аудио')
    elseif out:find('LOCAL_TTS_') then
      showErrorStatus('Ошибка')
      alert('Локальный голос не смог воспроизвести аудио')
    elseif out:find('command not found') or out:find('not found') then
      showErrorStatus('Ошибка')
      alert('Не найден один из voice backend-инструментов')
    elseif out:find('QWEN3_TTS_') then
      showErrorStatus('Ошибка')
      alert('TTS не сработал, включён fallback-голос')
    else
      showErrorStatus('Ошибка')
      alert('Ошибка voice hotkey')
    end
    voiceTaskRunning = false
  end, wrappedArgs)

  if not task then
    local tmpFile = args and args[1]
    if tmpFile and tmpFile ~= '' then
      cleanupFile(tmpFile)
    end
    voiceTaskRunning = false
    showErrorStatus('Ошибка')
    alert('Не удалось запустить voice task')
    return
  end

  task:setEnvironment(env)
  startVoiceStatusPolling('Готовлю озвучку')
  task:start()
end

local function runOnSelection(taskPath, successText)
  local originalClipboard = hs.pasteboard.getContents()
  local marker = '__VOICE_SELECTION_MARKER__' .. tostring(os.time()) .. tostring(math.random(1000, 9999))
  hs.pasteboard.setContents(marker)
  hs.eventtap.keyStroke({'cmd'}, 'c', 0)

  hs.timer.doAfter(0.28, function()
    local captured = hs.pasteboard.getContents() or ''
    restoreClipboard(originalClipboard)

    if captured == '' or captured == marker then
      alert('Сначала выдели текст, потом нажми хоткей')
      return
    end

    local tmpFile = os.tmpname()
    local handle = io.open(tmpFile, 'w')
    if not handle then
      alert('Не удалось сохранить выделенный текст')
      return
    end

    handle:write(captured)
    handle:close()
    runTask(taskPath, {tmpFile}, successText)
  end)
end

local function runOnClipboard(taskPath, successText)
  local captured = hs.pasteboard.getContents() or ''
  if captured == '' then
    alert('Сначала скопируй текст в буфер обмена')
    return
  end

  local tmpFile = os.tmpname()
  local handle = io.open(tmpFile, 'w')
  if not handle then
    alert('Не удалось сохранить текст из буфера')
    return
  end

  handle:write(captured)
  handle:close()
  runTask(taskPath, {tmpFile}, successText)
end

local function runOnSelectionOrClipboard(taskPath, successText)
  local originalClipboard = hs.pasteboard.getContents()
  local marker = '__VOICE_SELECTION_MARKER__' .. tostring(os.time()) .. tostring(math.random(1000, 9999))
  hs.pasteboard.setContents(marker)
  hs.eventtap.keyStroke({'cmd'}, 'c', 0)

  hs.timer.doAfter(0.28, function()
    local captured = hs.pasteboard.getContents() or ''
    restoreClipboard(originalClipboard)

    if captured == '' or captured == marker then
      captured = originalClipboard or ''
    end

    if captured == '' then
      alert('Выдели текст или скопируй его в буфер обмена')
      return
    end

    local tmpFile = os.tmpname()
    local handle = io.open(tmpFile, 'w')
    if not handle then
      alert('Не удалось сохранить текст')
      return
    end

    handle:write(captured)
    handle:close()
    runTask(taskPath, {tmpFile}, successText)
  end)
end

local function selectedVoiceTitle(settings, saluteVoice)
  if settings.tts_backend == 'local_fast' then
    return 'Локальный быстрый'
  end
  if settings.tts_backend == 'salute_tts' then
    return 'SaluteSpeech быстрый'
  end
  if settings.tts_backend == 'elevenlabs_tts' then
    return 'ElevenLabs красивый'
  end
  return settings.voice_label or 'Локальный быстрый'
end

local function buildVoiceMenu(settings, saluteVoice)
  return {
    {
      title = 'Текущий: ' .. selectedVoiceTitle(settings, saluteVoice),
      disabled = true,
    },
    { title = '-' },
    {
      title = 'Локальная простая быстрая модель',
      checked = settings.tts_backend == 'local_fast',
      fn = function()
        if selectLocalFastVoice() then
          alert('Голос: локальный быстрый')
        end
      end,
    },
    {
      title = 'SaluteSpeech: быстрый облачный',
      checked = settings.tts_backend == 'salute_tts',
      fn = function()
        if selectSaluteVoice(saluteVoice or 'Ost_24000') then
          alert('Голос: SaluteSpeech')
        end
      end,
    },
    {
      title = 'ElevenLabs: красивый голос',
      checked = settings.tts_backend == 'elevenlabs_tts',
      fn = function()
        if selectElevenLabsVoice() then
          alert('Голос: ElevenLabs')
        end
      end,
    },
  }
end

local function buildSettingsMenu()
  local settings = loadSettings()
  local saluteVoice = currentSaluteVoice()
  return {
    {
      title = brandName,
      disabled = true,
    },
    {
      title = brandVersion,
      disabled = true,
    },
    { title = '-' },
    {
      title = 'Провайдер summary: GigaChat API',
      checked = settings.summary_backend == 'gigachat_api',
      fn = function()
        settings.summary_backend = 'gigachat_api'
        saveSettings(settings)
        alert('Summary: GigaChat API')
      end,
    },
    {
      title = 'Провайдер summary: только GigaChat',
      disabled = true,
    },
    { title = '-' },
    {
      title = 'Провайдер пояснения: GigaChat',
      checked = settings.search_explain_backend == 'gigachat_api',
      fn = function()
        settings.search_explain_backend = 'gigachat_api'
        saveSettings(settings)
        alert('Пояснение: GigaChat')
      end,
    },
    {
      title = 'Голос: ' .. selectedVoiceTitle(settings, saluteVoice),
      menu = buildVoiceMenu(settings, saluteVoice),
    },
    { title = '-' },
    {
      title = 'Длина summary: коротко',
      checked = settings.summary_style == 'short',
      fn = function()
        settings.summary_style = 'short'
        saveSettings(settings)
        alert('Summary: коротко')
      end,
    },
    {
      title = 'Длина summary: сбалансированно',
      checked = settings.summary_style == 'balanced',
      fn = function()
        settings.summary_style = 'balanced'
        saveSettings(settings)
        alert('Summary: сбалансированно')
      end,
    },
    {
      title = 'Длина summary: подробнее',
      checked = settings.summary_style == 'detailed',
      fn = function()
        settings.summary_style = 'detailed'
        saveSettings(settings)
        alert('Summary: подробнее')
      end,
    },
    { title = '-' },
    {
      title = 'Подключить SaluteSpeech API',
      fn = function()
        configureSaluteToken()
      end,
    },
    {
      title = 'Подключить GigaChat API',
      fn = function()
        configureGigaChatToken()
      end,
    },
    {
      title = 'Подключить Brave Search API',
      fn = function()
        configureBraveToken()
      end,
    },
    {
      title = 'Подключить ElevenLabs API',
      fn = function()
        configureElevenLabsKey()
      end,
    },
    { title = '-' },
    {
      title = 'Режим: Local / SaluteSpeech / ElevenLabs',
      disabled = true,
    },
    {
      title = 'Проверить подключения',
      fn = function()
        runConnectionCheck()
      end,
    },
    {
      title = 'Открыть папку конфигов',
      fn = function()
        openConfigFolder()
      end,
    },
    {
      title = 'Сбросить настройки simple',
      fn = function()
        resetEnterpriseSettings()
      end,
    },
    { title = '-' },
    {
      title = 'Перезагрузить процесс',
      fn = function()
        restartVoiceProcess()
      end,
    },
  }
end

local function buildMainMenu()
  local settings = loadSettings()
  local saluteVoice = currentSaluteVoice()
  return {
    {
      title = brandName,
      disabled = true,
    },
    {
      title = brandVersion,
      disabled = true,
    },
    { title = '-' },
    {
      title = 'Озвучка текста',
      fn = function()
        runOnSelectionOrClipboard(speakCommand, 'Озвучка текста запущена')
      end,
    },
    {
      title = 'Саммари и озвучка',
      fn = function()
        runOnSelectionOrClipboard(summaryCommand, 'Саммари и озвучка запущены')
      end,
    },
    {
      title = 'Brave поиск + GPT-5.5 голосом',
      fn = function()
        runOnSelectionOrClipboard(searchExplainCommand, 'Brave поиск и GPT-5.5 запущены')
      end,
    },
    { title = '-' },
    {
      title = 'Голос: ' .. selectedVoiceTitle(settings, saluteVoice),
      menu = buildVoiceMenu(settings, saluteVoice),
    },
    {
      title = 'Настройки',
      menu = buildSettingsMenu(),
    },
    { title = '-' },
    {
      title = 'Стоп озвучка',
      fn = function()
        stopVoice()
      end,
    },
  }
end

if voiceStatusBar then
  voiceStatusBar:setMenu(buildMainMenu)
end

clearVoiceStatus()
saveSettings(loadSettings())

local hotkeysEnabled = false

if hotkeysEnabled then
  hs.hotkey.bind({'cmd'}, 'D', function()
    runOnSelectionOrClipboard(summaryCommand, 'Саммари и озвучка запущены')
  end)

  hs.hotkey.bind({'shift'}, 'Z', function()
    runOnSelectionOrClipboard(smartVoiceCommand, 'Умная озвучка запущена')
  end)

  hs.hotkey.bind({'shift'}, 'X', function()
    runOnSelectionOrClipboard(searchExplainCommand, 'Brave поиск и GPT-5.5 запущены')
  end)

  hs.hotkey.bind({'cmd', 'alt'}, 'V', function()
    runOnSelectionOrClipboard(speakCommand, 'Озвучка текста запущена')
  end)

  hs.hotkey.bind({'cmd', 'alt'}, 'S', function()
    runOnSelectionOrClipboard(summaryCommand, 'Саммари и озвучка запущены')
  end)

  hs.hotkey.bind({'cmd', 'alt'}, 'B', function()
    runOnSelectionOrClipboard(searchExplainCommand, 'Brave поиск и GPT-5.5 запущены')
  end)
end
