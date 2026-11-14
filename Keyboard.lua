local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- ========== إعدادات سريعة ==========
local CONFIG = {
	FOV = 120,
	SENSITIVITY = 1,
	JOY_DEADZONE = 0.3,
	PAD_SPEED = 1.5,
	ALLOW_MOUSE_INPUT = false, -- false = أزرار السكربت تستجيب للمس فقط
	CURSOR_OFFSET = Vector2.new(0, 0), -- لو بقي فرق ثابت بين النقطة والمؤشر عدّله هنا (بكسل)
	AIM_SENS_MULT = 0.6, -- حساسية الكاميرا أثناء Aim (أقل = تصويب أدق)
	AIM_MODE = "toggle",      -- "toggle" = ضغطة تشغّل/تطفّي | "hold" = تصويب طول ما ماسك الزر
	AIM_FOV_MULT = 0.8,       -- زوم FOV أثناء Aim (1 = بدون زوم)
	CAMERA_AUTODETECT = true, -- يكتشف تلقائيًا نوع كاميرا اللعبة ويضبط الدوران
	AIM_HOLD_RMB = true,  -- Aim يمسك الكليك اليمين (ADS) في ألعاب الأسلحة
	PC_MODE_AT_START = false, -- true = يشغّل وضع PC (تمويه قدرات الإدخال) أول ما يشتغل السكربت
	SHOW_CURSOR = true,        -- نقطة تبين مكان المؤشر في التراك باد
	CAMERA_METHOD = "script",  -- "script" = تدوير بالسكربت | "mouse" = حركة ماوس وهمية
	CAM_RAD_PER_PX = 0.0035,
	CAMERA_ONLY_RCLICK = true, -- الكاميرا تتحرك فقط من زر RClick
	CAMERA_SPEED = 1.5,
	SAVE_FILE = "mobile_controls_layout.json",
}

-- ========== GUI ==========
local gui = Instance.new("ScreenGui")
gui.Name = "BhopPCLayout"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- الـ GUI يغطي الشاشة كاملة بدون إزاحة الـ notch / الحواف الآمنة، عشان إحداثيات الـ GUI
-- تطابق إحداثيات الماوس (كانت النقطة تطلع بجنب مكان الكليك الفعلي)
pcall(function() gui.ScreenInsets = Enum.ScreenInsets.None end)
local probe = Instance.new("Frame")
probe.Name = "Origin"
probe.Size = UDim2.fromOffset(0, 0)
probe.Position = UDim2.fromOffset(0, 0)
probe.BackgroundTransparency = 1
probe.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

-- ========== الحفظ والتحميل ==========
local hasFS = type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"

local DEFAULT_ENABLED = {
	"Joystick", "Space", "LClick", "RClick", "Esc", "Enter", "Ctrl", "F", "I", "Emote",
	"ZoomIn", "ZoomOut", "ShiftLock", "MouseLock", "TouchMode", "Unstick", "RClickPlain", "LClickPlain", "DPad", "Aim",
}

-- الأماكن الافتراضية (نسبة من الشاشة)
local DEFAULT_POS = {
	Joystick  = { 0.04, 0.44 },
	Esc       = { 0.02, 0.04 },
	Enter     = { 0.10, 0.04 },
	Ctrl      = { 0.02, 0.21 },
	Unstick   = { 0.19, 0.04 },
	Emote     = { 0.764, 0.04 },
	I         = { 0.839, 0.04 },
	F         = { 0.914, 0.04 },
	ZoomIn    = { 0.744, 0.22 },
	ZoomOut   = { 0.744, 0.35 },
	MouseLock = { 0.831, 0.22 },
	TouchMode = { 0.831, 0.35 },
	LClick    = { 0.8625, 0.47 },
	RClick    = { 0.75, 0.53 },
	RClickPlain = { 0.64, 0.46 },
	LClickPlain = { 0.64, 0.28 },
	DPad = { 0.27, 0.45 },
	Aim = { 0.545, 0.68 },
	ShiftLock = { 0.6375, 0.667 },
	Space     = { 0.8125, 0.78 },
}

local state = { enabled = {}, pos = {}, scale = 1, fov = CONFIG.FOV, sens = CONFIG.SENSITIVITY }

do
	local loaded = false
	if hasFS then
		pcall(function()
			if isfile(CONFIG.SAVE_FILE) then
				local data = HttpService:JSONDecode(readfile(CONFIG.SAVE_FILE))
				if type(data) == "table" and type(data.enabled) == "table" then
					state = data
					loaded = true
				end
			end
		end)
	end
	if not loaded then
		for _, id in ipairs(DEFAULT_ENABLED) do
			state.enabled[id] = true
		end
	end
	state.enabled = state.enabled or {}
	local ver = tonumber(state.version) or 0
	if ver < 2 then state.enabled.RClickPlain = true end
	if ver < 3 then state.enabled.LClickPlain = true end
	if ver < 4 then
		state.enabled.DPad = true
		state.enabled.Aim = true
	end
	state.version = 4
	state.pos = state.pos or {}
	state.sizes = type(state.sizes) == "table" and state.sizes or {}
	state.scale = math.clamp(tonumber(state.scale) or 1, 0.5, 2)
	state.fov = math.clamp(tonumber(state.fov) or CONFIG.FOV, 30, 120)
	state.sens = math.clamp(tonumber(state.sens) or CONFIG.SENSITIVITY, 0.1, 3)
end

local saveQueued = false
local function saveState()
	if not hasFS or saveQueued then return end
	saveQueued = true
	task.delay(0.5, function()
		saveQueued = false
		pcall(function()
			writefile(CONFIG.SAVE_FILE, HttpService:JSONEncode(state))
		end)
	end)
end

-- ========== متغيرات مشتركة ==========
local virtualCursor = UserInputService:GetMouseLocation() -- مكان المؤشر الوهمي (ثابت بين اللمسات)
local rightHeld = false          -- RClick مضغوط
local effectiveLock = false      -- المؤشر مقفول في النص (يدوي أو منظور أول)
local mouseLocked = false        -- قفل يدوي
local lockOn = false             -- Shift Lock شغال
local aimOn = false              -- وضع التصويب (Aim) شغال

-- حساسية دوران الكاميرا (سلايدر Sensitivity) × مضاعف Aim
local function camSens()
	return state.sens * (aimOn and CONFIG.AIM_SENS_MULT or 1)
end
local pendingDelta = Vector2.zero
local camYaw, camPitch = 0, 0
local touchMode = "tap"          -- "tap" = لمس مباشر | "pad" = تراك باد
local editMode = false           -- وضع تعديل الأزرار
local editKind = "move"         -- "move" = تحريك | "delete" = حذف
local active = {}                -- id -> { obj, scale, stroke }

-- ========== نظام الأزرار المضغوطة (الحماية من التعليق) ==========
local held = {}

local function releaseBtn(btn)
	local h = held[btn]
	if not h then return end
	held[btn] = nil
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	pcall(h.release)
end

local function releaseAll()
	for btn in pairs(held) do
		releaseBtn(btn)
	end
end

RunService.Heartbeat:Connect(function()
	for btn, h in pairs(held) do
		local st = h.input.UserInputState
		if st ~= Enum.UserInputState.Begin and st ~= Enum.UserInputState.Change then
			releaseBtn(btn)
		elseif not btn.Parent then
			releaseBtn(btn)
		end
	end
end)

UserInputService.TouchEnded:Connect(function(input)
	for btn, h in pairs(held) do
		if h.input == input then releaseBtn(btn) end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	for btn, h in pairs(held) do
		if h.input == input then releaseBtn(btn) end
	end
end)

UserInputService.WindowFocusReleased:Connect(releaseAll)
player.CharacterRemoving:Connect(releaseAll)
gui.Destroying:Connect(releaseAll)

-- نقبل اللمس فقط: كليكات الماوس الوهمية تمر على الـ GUI وكانت تسبب حلقة تعليق
local function isPress(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return true
	end
	return CONFIG.ALLOW_MOUSE_INPUT and input.UserInputType == Enum.UserInputType.MouseButton1
end

-- ========== أدوات إنشاء الأزرار ==========
local function newButton(label, size)
	local btn = Instance.new("TextButton")
	btn.Name = label
	btn.Size = UDim2.fromOffset(size.X, size.Y)
	btn.BackgroundTransparency = 0.3
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	btn.Text = label
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.SourceSansBold
	btn.TextSize = 20
	btn.AutoButtonColor = false
	btn.Selectable = false
	btn.Parent = gui
	return btn
end

local function makeHoldButton(label, size, onDown, onUp)
	local btn = newButton(label, size)

	btn.InputBegan:Connect(function(input)
		if editMode or not isPress(input) or held[btn] then return end
		held[btn] = { input = input, release = onUp }
		btn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
		pcall(onDown)
	end)

	btn.InputEnded:Connect(function(input)
		local h = held[btn]
		if h and h.input == input then
			releaseBtn(btn)
		end
	end)

	return btn
end

-- ========== طبقة اللمس (لمس مباشر / تراك باد) ==========
local touchLayer = Instance.new("Frame")
touchLayer.Name = "TouchLayer"
touchLayer.Size = UDim2.new(1, 0, 1, 0)
touchLayer.BackgroundTransparency = 1
touchLayer.ZIndex = 0
touchLayer.Active = CONFIG.CAMERA_ONLY_RCLICK -- يمنع لمس الشاشة من تحريك كاميرا روبلوكس
touchLayer.Parent = gui

-- طبقة اللمس Active عشان تمنع كاميرا روبلوكس الافتراضية، لكنها كانت تبلع كليكات الماوس الوهمية
-- فما توصل للعبة (الأسلحة ما تطلق). نطفيها لحظة إرسال الكليك فقط ثم نرجعها.
local clickPass = 0
local function passFlash()
	clickPass += 1
	touchLayer.Active = false
	task.delay(0.15, function()
		clickPass = math.max(0, clickPass - 1)
		if clickPass == 0 then
			touchLayer.Active = CONFIG.CAMERA_ONLY_RCLICK
		end
	end)
end

local lastSent = nil
local calOffset = Vector2.zero -- إزاحة المعايرة (تخلي المؤشر الحقيقي ينزل على النقطة)
if type(state.cal) == "table" and type(state.cal.x) == "number" and type(state.cal.y) == "number" then
	calOffset = Vector2.new(state.cal.x, state.cal.y)
end
local function mp(p)
	return p + CONFIG.CURSOR_OFFSET + (effectiveLock and Vector2.zero or calOffset)
end
local function sendMove(p)
	lastSent = p
	local q = mp(p)
	VirtualInputManager:SendMouseMoveEvent(q.X, q.Y, game)
end
local function sendClick(p, down)
	passFlash()
	local q = mp(p)
	VirtualInputManager:SendMouseButtonEvent(q.X, q.Y, 0, down, game, 0)
end

-- معايرة تلقائية: نرسل المؤشر لنقطة معروفة ونقرأ وين وصل فعليًا، ونعوّض الفرق.
-- بعدها المؤشر الحقيقي ينزل بالضبط على النقطة (النقطة هي اللي تحدد مكان الكليك).
local calibrating = false
local function calibrateCursor()
	if calibrating then return false end
	calibrating = true
	local ok = false
	local cam = Workspace.CurrentCamera
	if cam then
		local target = cam.ViewportSize / 2
		local prev = calOffset
		calOffset = Vector2.zero
		for _ = 1, 4 do
			local q = mp(target)
			VirtualInputManager:SendMouseMoveEvent(q.X, q.Y, game)
			RunService.Heartbeat:Wait()
			RunService.Heartbeat:Wait()
			local resid = UserInputService:GetMouseLocation() - target
			if resid.Magnitude > 500 then break end
			if resid.Magnitude < 2 then
				ok = true
				break
			end
			calOffset = calOffset - resid
		end
		if not ok then calOffset = prev end
	end
	calibrating = false
	return ok
end

local lastMoveT = 0
local function sendMoveThrottled(p)
	local now = os.clock()
	if now - lastMoveT >= 1 / 60 then
		lastMoveT = now
		sendMove(p)
	end
end

-- نقطة المؤشر المرئية (تراك باد)
local cursorDot = Instance.new("Frame")
cursorDot.Name = "VirtualCursor"
cursorDot.Size = UDim2.new(0, 14, 0, 14)
cursorDot.AnchorPoint = Vector2.new(0.5, 0.5)
cursorDot.BackgroundColor3 = Color3.new(1, 1, 1)
cursorDot.ZIndex = 10
cursorDot.Visible = false
cursorDot.Parent = gui
Instance.new("UICorner", cursorDot).CornerRadius = UDim.new(1, 0)
local dotStroke = Instance.new("UIStroke", cursorDot)
dotStroke.Color = Color3.new(0, 0, 0)
dotStroke.Thickness = 2

RunService.RenderStepped:Connect(function()
	local show = CONFIG.SHOW_CURSOR and not editMode and (touchMode == "pad" and not effectiveLock)
	cursorDot.Visible = show
	if show then
		if effectiveLock then
			-- مؤشر مقفول بالنص: نقطة التصويب في مركز الشاشة بالضبط
			cursorDot.Position = UDim2.new(0.5, 0, 0.5, 0)
		else
			local o = probe.AbsolutePosition
			cursorDot.Position = UDim2.fromOffset(virtualCursor.X - o.X, virtualCursor.Y - o.Y)
		end
	end
end)

touchLayer.InputBegan:Connect(function(input)
	if editMode or not isPress(input) then return end
	-- لمسة قديمة عالقة؟ نفكها ونبدأ الجديدة
	if held[touchLayer] then releaseBtn(touchLayer) end

	local inset = GuiService:GetGuiInset()
	local startT = os.clock()
	local startPos = Vector2.new(input.Position.X, input.Position.Y)
	local lastPos = startPos
	local moved = 0
	local isDown = false
	local cancelled = false
	local lastVirtual = startPos + inset
	-- أثناء تحريك الكاميرا (RClick أو منظور أول) نستخدم حركة نسبية دائمًا
	local mode = (rightHeld or effectiveLock) and "pad" or touchMode

	local function update()
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if mode == "tap" then
			if rightHeld then return end
			lastVirtual = pos + inset
			virtualCursor = lastVirtual
			sendMoveThrottled(lastVirtual)
		else
			local delta = pos - lastPos
			lastPos = pos
			moved += delta.Magnitude
			if rightHeld then
				-- RClick مضغوط: تحريك الكاميرا
				pendingDelta += delta * CONFIG.CAMERA_SPEED * camSens()
			elseif effectiveLock then
				-- المؤشر مقفول: الكاميرا ما تتحرك إلا من RClick
				if lockOn or aimOn or not CONFIG.CAMERA_ONLY_RCLICK then
					pendingDelta += delta * CONFIG.CAMERA_SPEED * camSens()
				end
			else
				local vp = Workspace.CurrentCamera.ViewportSize
				virtualCursor = Vector2.new(
					math.clamp(virtualCursor.X + delta.X * CONFIG.PAD_SPEED, 0, vp.X),
					math.clamp(virtualCursor.Y + delta.Y * CONFIG.PAD_SPEED, 0, vp.Y)
				)
				sendMoveThrottled(virtualCursor)
			end
		end
	end

	local function release()
		cancelled = true
		if mode == "tap" then
			if isDown then
				isDown = false
				sendMove(lastVirtual)
				sendClick(lastVirtual, false)
			end
		else
			-- لمسة سريعة بدون حركة = كليك في مكان المؤشر
			if os.clock() - startT < 0.25 and moved < 12 and not rightHeld then
				local p = virtualCursor
				task.spawn(function()
					sendMove(p)
					sendClick(p, true)
					task.wait(0.03)
					sendClick(p, false)
				end)
			end
		end
	end

	held[touchLayer] = { input = input, release = release, update = update }

	if mode == "tap" then
		-- ننقل المؤشر أولًا وننتظر إطار عشان الكليك ما يطلع في المكان القديم
		virtualCursor = lastVirtual
		sendMove(lastVirtual)
		task.spawn(function()
			RunService.Heartbeat:Wait()
			if cancelled then
				sendClick(lastVirtual, true)
				task.wait(0.03)
				sendClick(lastVirtual, false)
			else
				sendClick(lastVirtual, true)
				isDown = true
			end
		end)
	end
end)

touchLayer.InputEnded:Connect(function(input)
	local h = held[touchLayer]
	if h and h.input == input then
		releaseBtn(touchLayer)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	local ht = held[touchLayer]
	if ht and input == ht.input then
		ht.update()
	end
end)

-- ========== قفل الماوس + منظور أول + تدوير الكاميرا ==========
local lastWant = false
RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	local firstPerson = false
	if cam then
		firstPerson = (cam.CFrame.Position - cam.Focus.Position).Magnitude < 1
			or player.CameraMode == Enum.CameraMode.LockFirstPerson
	end

	-- مقفول يدويًا أو في المنظور الأول = المؤشر في النص
	local want = mouseLocked or firstPerson or lockOn or aimOn
	effectiveLock = want

	if want ~= lastWant then
		lastWant = want
		if not want then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	if want then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
		if cam then virtualCursor = cam.ViewportSize / 2 end
	elseif rightHeld then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end

	-- نتأكد إن المؤشر الفعلي وصل لمكان النقطة (آخر تحريك كان ينتهي بدون إرسال)
	if not want and not rightHeld and not editMode and lastSent ~= nil and lastSent ~= virtualCursor then
		sendMove(virtualCursor)
	end

	-- حركة الكاميرا المجمّعة (مرة وحدة كل إطار)
	if pendingDelta.Magnitude > 0 then
		if CONFIG.CAMERA_METHOD == "script" then
			local k = CONFIG.CAM_RAD_PER_PX
			camYaw -= pendingDelta.X * k
			camPitch -= pendingDelta.Y * k
		else
			local base = virtualCursor
			VirtualInputManager:SendMouseMoveEvent(base.X + pendingDelta.X, base.Y + pendingDelta.Y, game)
		end
		pendingDelta = Vector2.zero
	end
end)

local function rotAbout(c, f, axis, ang)
	return CFrame.new(f) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-f) * c
end

-- دوران الكاميرا بالسكربت، بوضعين يُكتشفون تلقائيًا:
--  • تزايدي: كاميرا روبلوكس الافتراضية تقرأ اتجاهها من CFrame الحالي، فنطبق الدوران كزيادة لمرة وحدة
--  • ثابت: كاميرات الألعاب اللي ترجّع نفسها كل إطار، فنطبق الدوران التراكمي كل إطار فوق كاميرا اللعبة
local camPersistent = false
local accYaw, accPitch = 0, 0
local lastLook = nil
local mismatchHits = 0

RunService:BindToRenderStep("MobileCamOffset", Enum.RenderPriority.Last.Value, function()
	local cam = Workspace.CurrentCamera
	if CONFIG.CAMERA_METHOD ~= "script" or not cam or cam.CameraType == Enum.CameraType.Scriptable then
		camYaw, camPitch = 0, 0
		accYaw, accPitch = 0, 0
		lastLook = nil
		return
	end

	local dYaw, dPitch = camYaw, camPitch
	camYaw, camPitch = 0, 0

	-- كشف نوع الكاميرا: هل احتفظت بتدويرنا من الإطار السابق؟
	if CONFIG.CAMERA_AUTODETECT and lastLook and (math.abs(accYaw) + math.abs(accPitch)) > 0.05 then
		local d = (cam.CFrame.LookVector - lastLook).Magnitude
		if camPersistent then
			if d < 0.01 then
				-- الكاميرا صارت تحتفظ بتدويرنا: نرجع للوضع التزايدي
				camPersistent = false
				accYaw, accPitch = 0, 0
				lastLook = nil
				mismatchHits = 0
			end
		else
			if d > 0.02 then
				mismatchHits += 1
				if mismatchHits >= 3 then
					camPersistent = true
					mismatchHits = 0
				end
			else
				mismatchHits = 0
			end
		end
	end

	accYaw += dYaw
	accPitch += dPitch

	local f = cam.Focus.Position
	local cf
	if camPersistent then
		if accYaw == 0 and accPitch == 0 then return end
		cf = rotAbout(cam.CFrame, f, Vector3.yAxis, accYaw)
		local pitch = math.asin(math.clamp(cf.LookVector.Y, -1, 1))
		accPitch = math.clamp(pitch + accPitch, -1.35, 1.35) - pitch
		cf = rotAbout(cf, f, cf.RightVector, accPitch)
	else
		if dYaw == 0 and dPitch == 0 then return end
		cf = rotAbout(cam.CFrame, f, Vector3.yAxis, dYaw)
		local pitch = math.asin(math.clamp(cf.LookVector.Y, -1, 1))
		dPitch = math.clamp(pitch + dPitch, -1.35, 1.35) - pitch
		cf = rotAbout(cf, f, cf.RightVector, dPitch)
	end
	cam.CFrame = cf
	lastLook = cf.LookVector
end)

player.CharacterAdded:Connect(function()
	camYaw, camPitch = 0, 0
	accYaw, accPitch = 0, 0
	lastLook = nil
	camPersistent = false
	mismatchHits = 0
end)

-- ========== محرك Shift Lock + Aim (مدمج من سكربت Shift Lock) ==========
-- إعدادات المحرك (تنحفظ مع باقي الإعدادات، وتتعدل من ⚙ ← تبويب Shift Lock)
local SL = {
	Smooth = false,           -- حركة سلسة للإزاحة
	SeeThrough = true,        -- الجدران بينك وبين الكاميرا تصير شفافة (Invisicam)
	Vibrate = true,           -- اهتزاز الجوال لما تشغّل Shift Lock
	VibrationStrength = 1,
	VibrationTime = 0.25,
	Offset = 1.75,            -- إزاحة الكاميرا للكتف (سالب = الكتف الأيسر)
	AimOffset = 0.85,         -- إزاحة الكاميرا أثناء Aim
	AimZoom = CONFIG.AIM_FOV_MULT, -- زوم FOV أثناء Aim (1 = بدون زوم)
}
if type(state.sl) == "table" then
	for k, v in pairs(SL) do
		if type(state.sl[k]) == type(v) then SL[k] = state.sl[k] end
	end
end
SL.VibrationStrength = math.clamp(SL.VibrationStrength, 0.1, 1)
SL.VibrationTime = math.clamp(SL.VibrationTime, 0.05, 1)
SL.Offset = math.clamp(SL.Offset, -5, 5)
SL.AimOffset = math.clamp(SL.AimOffset, 0, 3)
SL.AimZoom = math.clamp(SL.AimZoom, 0.4, 1)
state.sl = SL

local setShiftLock, vibrate

do
	local HapticService = game:GetService("HapticService")
	local okUGS2, slUGS = pcall(function()
		return UserSettings():GetService("UserGameSettings")
	end)
	local isTouchDevice = UserInputService.TouchEnabled -- نقرأها مرة وحدة (قبل أي تمويه PC)
	local mouse = player:GetMouse()
	local hookActive = true

	-- علامة التصويب في مركز الشاشة
	local Crosshair = Instance.new("ImageLabel")
	Crosshair.Name = "Crosshair"
	Crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	Crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
	Crosshair.Size = UDim2.fromOffset(32, 32)
	Crosshair.BackgroundTransparency = 1
	Crosshair.Image = "rbxasset://textures/MouseLockedCursor.png"
	Crosshair.ZIndex = 10
	Crosshair.Visible = false
	Crosshair.Parent = gui

	-- اهتزاز الجوال (روبلوكس تقول اللمس غير مدعوم، لكن الجوالات تهتز عبر Gamepad1)
	function vibrate(force)
		if not force and not SL.Vibrate then return end
		task.spawn(function()
			pcall(function()
				local pad = Enum.UserInputType.Gamepad1
				HapticService:SetMotor(pad, Enum.VibrationMotor.Large, SL.VibrationStrength)
				task.wait(SL.VibrationTime)
				HapticService:SetMotor(pad, Enum.VibrationMotor.Large, 0)
			end)
		end)
	end

	function setShiftLock(on)
		lockOn = on
		local e = active.ShiftLock
		if e then
			e.obj.BackgroundColor3 = on and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 40)
		end
		if on then
			vibrate()
			pcall(function()
				if slUGS then
					slUGS.ComputerCameraMovementMode = Enum.ComputerCameraMovementMode.Classic
					slUGS.TouchCameraMovementMode = Enum.TouchCameraMovementMode.Classic
				end
			end)
		end
	end

	local function syncRotation(enabled)
		pcall(function()
			if not slUGS then return end
			local want = enabled and Enum.RotationType.CameraRelative or Enum.RotationType.MovementRelative
			if slUGS.RotationType ~= want then slUGS.RotationType = want end
		end)
	end

	local function hasToolEquipped()
		local character = player.Character
		return character ~= nil and character:FindFirstChildOfClass("Tool") ~= nil
	end

	-- نقطة الأصابع/الماوس = علامة التصويب: أي أداة (سلاح/سيف/بناء) تقرأ Mouse.Hit/Target/X/Y/UnitRay
	local function crosshairHit()
		local cam = Workspace.CurrentCamera
		if not cam then return nil end
		local vp = cam.ViewportSize
		local px, py = vp.X / 2, vp.Y / 2
		local ray = cam:ViewportPointToRay(px, py)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, gui }
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		local pos = result and result.Position or (ray.Origin + ray.Direction * 1000)
		return pos, result and result.Instance, ray, px, py
	end

	if type(hookmetamethod) == "function" and type(newcclosure) == "function"
		and type(checkcaller) == "function" then
		local oldIndex
		oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
			if hookActive and self == mouse and isTouchDevice and (lockOn or aimOn) and not checkcaller() then
				if key == "Hit" or key == "Target" or key == "X" or key == "Y" or key == "UnitRay" then
					local ok, pos, target, ray, px, py = pcall(crosshairHit)
					if ok and pos then
						if key == "Hit" then return CFrame.new(pos) end
						if key == "Target" then return target end
						if key == "X" then return px end
						if key == "Y" then return py end
						if key == "UnitRay" then return ray end
					end
				end
			end
			return oldIndex(self, key)
		end))

		if type(getnamecallmethod) == "function" then
			local oldNamecall
			oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
				local method = getnamecallmethod()
				if hookActive and isTouchDevice and (lockOn or aimOn) and not checkcaller() then
					if method == "GetMouseLocation" and self == UserInputService then
						local cam = Workspace.CurrentCamera
						if cam then
							local vp = cam.ViewportSize
							return Vector2.new(vp.X / 2, vp.Y / 2)
						end
					elseif (method == "ViewportPointToRay" or method == "ScreenPointToRay") and hasToolEquipped() then
						local cam = Workspace.CurrentCamera
						if cam and self == cam then
							local vp = cam.ViewportSize
							local cx, cy = vp.X / 2, vp.Y / 2
							if method == "ScreenPointToRay" then
								local inset = GuiService:GetGuiInset()
								cx, cy = cx - inset.X, cy - inset.Y
							end
							local _, _, depth = ...
							if setnamecallmethod then setnamecallmethod(method) end
							if depth ~= nil then return oldNamecall(self, cx, cy, depth) end
							return oldNamecall(self, cx, cy)
						end
					end
				end
				if setnamecallmethod then setnamecallmethod(method) end
				return oldNamecall(self, ...)
			end))
		end
	end

	-- ClickDetector تحت علامة التصويب (عشان الأزرار/الأبواب تشتغل بالكليك مع Shift Lock/Aim)
	local lastClickTime = 0
	local function detectorUnderCrosshair()
		local cam = Workspace.CurrentCamera
		if not cam then return nil, nil end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { player.Character, gui }
		local result = Workspace:Raycast(cam.CFrame.Position, cam.CFrame.LookVector * 1000, params)
		if not result or not result.Instance then return nil, nil end
		local part = result.Instance
		local detector = part:FindFirstChildOfClass("ClickDetector")
		if not detector and part.Parent then
			detector = part.Parent:FindFirstChildOfClass("ClickDetector")
		end
		if detector and (part.Position - cam.CFrame.Position).Magnitude <= detector.MaxActivationDistance then
			return part, detector
		end
		return nil, nil
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe or not (lockOn or aimOn) then return end
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.Touch then
			if tick() - lastClickTime < 0.15 then return end
			local part, detector = detectorUnderCrosshair()
			if part and detector then
				lastClickTime = tick()
				pcall(function()
					if fireclickdetector then
						fireclickdetector(detector)
					else
						detector.MouseClick:Fire(player)
					end
				end)
			end
		end
	end)

	-- الكاميرا: إزاحة الكتف + دوران الشخصية + رؤية من خلال الجدران + علامة التصويب
	local function approach(cur, target, dt, speed)
		if SL.Smooth then
			return cur + (target - cur) * math.clamp(dt * speed, 0, 1)
		end
		return target
	end

	local smoothedOffset = 0
	local wasLockActive = false
	local healT = 0

	RunService:BindToRenderStep("MC_ShiftLock", Enum.RenderPriority.Camera.Value + 1, function(dt)
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local dead = (not humanoid or humanoid.Health <= 0 or not root)
		local animated = (not dead) and (cam.CameraType == Enum.CameraType.Scriptable or cam.CameraSubject ~= humanoid)

		local lockActive = lockOn or aimOn
		if lockActive then
			wasLockActive = true
			syncRotation(true)
			pcall(function()
				local want = SL.SeeThrough and Enum.DevCameraOcclusionMode.Invisicam or Enum.DevCameraOcclusionMode.Zoom
				if player.DevCameraOcclusionMode ~= want then player.DevCameraOcclusionMode = want end
			end)
			healT += dt
			if healT > 1 then
				healT = 0
				pcall(function() player.DevEnableMouseLock = false end)
			end
		elseif wasLockActive then
			wasLockActive = false
			syncRotation(false)
			pcall(function() player.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Zoom end)
		end
		Crosshair.Visible = lockActive and not animated and not editMode

		local dist = (cam.Focus.Position - cam.CFrame.Position).Magnitude
		local firstPerson = dist < 0.999
		local base = SL.Offset
		if aimOn then
			-- التصويب يقرّب الكاميرا للنص، وما يبعدها أكثر من الإزاحة العادية
			base = (base >= 0) and math.min(SL.AimOffset, base) or math.max(-SL.AimOffset, base)
		end
		local target = (lockActive and not firstPerson and not animated) and base or 0
		smoothedOffset = approach(smoothedOffset, target, dt, 20)

		if smoothedOffset ~= 0 or lockActive then
			local shifted = cam.CFrame * CFrame.new(smoothedOffset, aimOn and 0.2 or 0, 0)
			cam.CFrame = shifted
			cam.Focus = shifted * CFrame.new(0, 0, -dist)
		end
	end)
end

-- قفل الماوس اليدوي
local function setMouseLock(on)
	mouseLocked = on
	local e = active.MouseLock
	if e then
		e.obj.Text = on and "فتح الماوس" or "قفل الماوس"
		e.obj.BackgroundColor3 = on and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(40, 40, 40)
	end
	if not on and not effectiveLock then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

UserInputService.WindowFocusReleased:Connect(function()
	if mouseLocked then setMouseLock(false) end
end)
player.CharacterRemoving:Connect(function()
	if mouseLocked then setMouseLock(false) end
end)

-- وضع التصويب (Aim): مؤشر بالنص + سحب الشاشة يحرك الكاميرا + (اختياري) يمسك الكليك اليمين ADS
local function setAim(on)
	aimOn = on
	local e = active.Aim
	if e then
		e.obj.Text = on and "AIM ●" or "AIM"
		e.obj.BackgroundColor3 = on and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(40, 40, 40)
	end
	local cam = Workspace.CurrentCamera
	if cam then virtualCursor = cam.ViewportSize / 2 end
	if CONFIG.AIM_HOLD_RMB then
		passFlash()
		local q = mp(virtualCursor)
		VirtualInputManager:SendMouseButtonEvent(q.X, q.Y, 1, on, game, 0)
	end
end

-- ========== FOV + الحساسية ==========
local currentFOV = state.fov

local fovMult = 1
RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	local targetMult = aimOn and SL.AimZoom or 1
	fovMult = fovMult + (targetMult - fovMult) * 0.25
	local fov = currentFOV * fovMult
	if math.abs(cam.FieldOfView - fov) > 0.01 then
		cam.FieldOfView = fov
	end
end)

local okUGS, UGS = pcall(function()
	return UserSettings():GetService("UserGameSettings")
end)
local defaultSens = okUGS and UGS.MouseSensitivity or 1

local function applySens(v)
	if okUGS then
		pcall(function()
			UGS.MouseSensitivity = defaultSens * v
		end)
	end
end

-- ========== بنّائين الأزرار ==========
-- أزرار ماوس (0 = يسار، 1 = يمين، 2 = وسط)
-- plain = true: كليك عادي بدون تحريك كاميرا (للزر الأيمن)
local function buildMouseButton(label, size, button, plain)
	local isCam = (button == 1 and not plain)
	local gen = 0
	local downSent = false

	local function btn(p, down)
		passFlash()
		local q = mp(p)
		VirtualInputManager:SendMouseButtonEvent(q.X, q.Y, button, down, game, 0)
	end

	local function send(isDown)
		local p = virtualCursor

		if isCam then
			-- RClick: المؤشر يثبت مكانه طول ما الزر مضغوط (الكاميرا بس تتحرك)
			rightHeld = isDown
			pendingDelta = Vector2.zero
			passFlash()
			local q = mp(p)
			if isDown then
				VirtualInputManager:SendMouseMoveEvent(q.X, q.Y, game)
				VirtualInputManager:SendMouseButtonEvent(q.X, q.Y, 1, true, game, 0)
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
			else
				VirtualInputManager:SendMouseButtonEvent(q.X, q.Y, 1, false, game, 0)
				VirtualInputManager:SendMouseMoveEvent(q.X, q.Y, game) -- يرجع المؤشر لمكانه
				if not effectiveLock then
					UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				end
			end
			return
		end

		gen += 1
		local my = gen
		if isDown then
			-- ننقل المؤشر لمكان النقطة وننتظر إطار عشان الكليك ما يطلع في المكان القديم
			sendMove(p)
			RunService.Heartbeat:Wait()
			if gen ~= my then return end
			btn(p, true)
			downSent = true
		else
			if downSent then
				downSent = false
				btn(p, false)
			else
				-- رفعت إصبعك قبل ما ينرسل الضغط: نسوي كليك كامل
				task.spawn(function()
					sendMove(p)
					RunService.Heartbeat:Wait()
					btn(p, true)
					task.wait(0.03)
					btn(p, false)
				end)
			end
		end
	end

	local b = makeHoldButton(label, size,
		function() send(true) end,
		function() send(false) end
	)

	-- RClick: اسحب إصبعك على الزر نفسه عشان تحرك الكاميرا (بإصبع واحد)
	if isCam then
		local lastPos
		b.InputBegan:Connect(function(input)
			if isPress(input) then
				lastPos = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
		local conn
		conn = UserInputService.InputChanged:Connect(function(input)
			if not b.Parent then
				conn:Disconnect()
				return
			end
			local h = held[b]
			if h and input == h.input and lastPos then
				local pos = Vector2.new(input.Position.X, input.Position.Y)
				pendingDelta += (pos - lastPos) * CONFIG.CAMERA_SPEED * camSens()
				lastPos = pos
			end
		end)
	end

	return b
end

-- أسهم الزوم (عجلة الماوس)
local function buildScrollButton(label, size, forwards)
	local token = 0
	return makeHoldButton(label, size,
		function()
			token += 1
			local my = token
			task.spawn(function()
				while token == my do
					local p = mp(virtualCursor)
					VirtualInputManager:SendMouseWheelEvent(p.X, p.Y, forwards, game)
					task.wait(0.08)
				end
			end)
		end,
		function() token += 1 end
	)
end

-- زر كيبورد
local function buildKeyButton(label, size, keycode)
	local key = Enum.KeyCode[keycode]
	local b = makeHoldButton(label, size,
		function() VirtualInputManager:SendKeyEvent(true, key, false, game) end,
		function() VirtualInputManager:SendKeyEvent(false, key, false, game) end
	)
	if #label > 3 then b.TextSize = 16 end
	return b
end

-- جويستك WASD
local function buildJoystick(size)
	local joyKeys = { W = false, A = false, S = false, D = false }

	local function setJoyKey(name, down)
		if joyKeys[name] == down then return end
		joyKeys[name] = down
		VirtualInputManager:SendKeyEvent(down, Enum.KeyCode[name], false, game)
	end

	local base = Instance.new("Frame")
	base.Name = "Joystick"
	base.Size = UDim2.fromOffset(size.X, size.Y)
	base.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	base.BackgroundTransparency = 0.3
	base.Active = true
	base.Parent = gui
	Instance.new("UICorner", base).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 70, 0, 70)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	knob.BackgroundTransparency = 0.2
	knob.Parent = base
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function releaseJoystick()
		for name in pairs(joyKeys) do
			setJoyKey(name, false)
		end
		knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	end

	local function updateJoystick(input)
		local sz = base.AbsoluteSize
		local center = base.AbsolutePosition + sz / 2
		local offset = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = sz.X / 2
		-- الإصبع برا الدائرة؟ الكرة تثبت على الحافة باتجاه الإصبع وتكمل تتحكم
		local travel = radius * 0.8

		local clamped = offset
		if offset.Magnitude > travel then
			clamped = offset.Unit * travel
		end
		-- بالنسبة (scale) عشان يشتغل مع تكبير/تصغير الأزرار
		knob.Position = UDim2.new(0.5 + clamped.X / sz.X, 0, 0.5 + clamped.Y / sz.Y, 0)

		local nx, ny = clamped.X / travel, clamped.Y / travel
		setJoyKey("W", ny < -CONFIG.JOY_DEADZONE)
		setJoyKey("S", ny > CONFIG.JOY_DEADZONE)
		setJoyKey("A", nx < -CONFIG.JOY_DEADZONE)
		setJoyKey("D", nx > CONFIG.JOY_DEADZONE)
	end

	base.InputBegan:Connect(function(input)
		if editMode or not isPress(input) or held[base] then return end
		held[base] = { input = input, release = releaseJoystick }
		updateJoystick(input)
	end)

	-- الرفع يجي من المعالجات العامة (TouchEnded / InputEnded / الحارس)، فالجويستك يكمل يتبع الإصبع حتى لو طلع برا الدائرة

	local conn
	conn = UserInputService.InputChanged:Connect(function(input)
		if not base.Parent then
			conn:Disconnect()
			return
		end
		local h = held[base]
		if h and input == h.input then
			updateJoystick(h.input)
		end
	end)

	return base
end

-- ========== أدوات (أزرار تبديل) ==========
local function buildShiftLock(size)
	local b = newButton("◎", size)
	b.TextSize = 36
	Instance.new("UICorner", b).CornerRadius = UDim.new(1, 0)
	b.BackgroundColor3 = lockOn and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 40)
	b.Activated:Connect(function()
		if editMode then return end
		setShiftLock(not lockOn)
	end)
	return b
end

local function buildMouseLock(size)
	local b = newButton(mouseLocked and "فتح الماوس" or "قفل الماوس", size)
	b.TextSize = 18
	b.BackgroundColor3 = mouseLocked and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(40, 40, 40)
	b.Activated:Connect(function()
		if editMode then return end
		setMouseLock(not mouseLocked)
	end)
	return b
end

local function touchModeText()
	return touchMode == "tap" and "لمس مباشر" or "تراك باد"
end

local function buildTouchMode(size)
	local b = newButton(touchModeText(), size)
	b.TextSize = 18
	b.Activated:Connect(function()
		if editMode then return end
		touchMode = (touchMode == "tap") and "pad" or "tap"
		b.Text = touchModeText()
	end)
	return b
end

local function buildUnstick(size)
	local b = newButton("فك التعليق", size)
	b.TextSize = 18
	b.Activated:Connect(function()
		if editMode then return end
		releaseAll()
		if aimOn then setAim(false) end
		rightHeld = false
		pendingDelta = Vector2.zero
		if not effectiveLock then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		local p = mp(virtualCursor)
		for btn = 0, 2 do
			VirtualInputManager:SendMouseButtonEvent(p.X, p.Y, btn, false, game, 0)
		end
		for _, k in ipairs({ "W", "A", "S", "D", "Space", "LeftShift", "LeftControl" }) do
			VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[k], false, game)
		end
	end)
	return b
end

-- D-Pad: أسهم ▲◀▶▼ تحرك WASD (8 اتجاهات: لمس بين سهمين = قطري)
local function buildDPad(size)
	local keys = { W = false, A = false, S = false, D = false }

	local function setKey(name, down)
		if keys[name] == down then return end
		keys[name] = down
		VirtualInputManager:SendKeyEvent(down, Enum.KeyCode[name], false, game)
	end

	local base = Instance.new("Frame")
	base.Name = "DPad"
	base.Size = UDim2.fromOffset(size.X, size.Y)
	base.BackgroundTransparency = 1
	base.Active = true
	base.Parent = gui

	local arrows = {}
	local function arrow(name, txt, ax, ay)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(0.33, 0, 0.33, 0)
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.new(ax, 0, ay, 0)
		l.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		l.BackgroundTransparency = 0.3
		l.Text = txt
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.SourceSansBold
		l.TextSize = 26
		l.Parent = base
		Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
		arrows[name] = l
	end
	arrow("W", "▲", 0.5, 0.17)
	arrow("S", "▼", 0.5, 0.83)
	arrow("A", "◀", 0.17, 0.5)
	arrow("D", "▶", 0.83, 0.5)

	-- كرة تتبع الإصبع (مثل الجويستك)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0.3, 0, 0.3, 0)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0.5, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
	knob.BackgroundTransparency = 0.25
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = base
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh()
		for name, l in pairs(arrows) do
			l.BackgroundColor3 = keys[name] and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(40, 40, 40)
		end
	end

	local function release()
		for name in pairs(keys) do
			setKey(name, false)
		end
		knob.Position = UDim2.new(0.5, 0, 0.5, 0)
		refresh()
	end

	local function update(input)
		local sz = base.AbsoluteSize
		local center = base.AbsolutePosition + sz / 2
		local off = Vector2.new(input.Position.X, input.Position.Y) - center
		local radius = sz.X / 2

		-- الكرة تتبع الإصبع وتثبت على الحافة لو الإصبع برا
		local travel = radius * 0.62
		local clamped = off
		if off.Magnitude > travel then
			clamped = off.Unit * travel
		end
		knob.Position = UDim2.new(0.5 + clamped.X / sz.X, 0, 0.5 + clamped.Y / sz.Y, 0)

		if off.Magnitude < radius * 0.18 then
			for name in pairs(keys) do setKey(name, false) end
		else
			local u = off.Unit
			setKey("W", u.Y < -0.38)
			setKey("S", u.Y > 0.38)
			setKey("A", u.X < -0.38)
			setKey("D", u.X > 0.38)
		end
		refresh()
	end

	base.InputBegan:Connect(function(input)
		if editMode or not isPress(input) or held[base] then return end
		held[base] = { input = input, release = release }
		update(input)
	end)

	-- الرفع يجي من المعالجات العامة، فالـ D-Pad يكمل يتبع الإصبع حتى لو طلع برا

	local conn
	conn = UserInputService.InputChanged:Connect(function(input)
		if not base.Parent then
			conn:Disconnect()
			return
		end
		local h = held[base]
		if h and input == h.input then
			update(h.input)
		end
	end)

	return base
end

-- زر Aim (تصويب)
local function buildAim(size)
	if CONFIG.AIM_MODE == "hold" then
		-- تصويب طول ما ماسك الزر (والإصبع الثاني يحرك الكاميرا)
		local hb = makeHoldButton("AIM", size,
			function() setAim(true) end,
			function() setAim(false) end
		)
		hb.TextSize = 22
		return hb
	end
	local b = newButton(aimOn and "AIM ●" or "AIM", size)
	b.TextSize = 22
	b.BackgroundColor3 = aimOn and Color3.fromRGB(200, 60, 60) or Color3.fromRGB(40, 40, 40)
	b.Activated:Connect(function()
		if editMode then return end
		setAim(not aimOn)
	end)
	return b
end

-- ========== وضع PC (تجريبي): تمويه قدرات الإدخال على سكربتات اللعبة ==========
-- الألعاب تحدد "جوال أو كمبيوتر" من خصائص UserInputService (TouchEnabled / KeyboardEnabled ...)
-- هنا نخلي سكربتات اللعبة (مو سكربتنا) تشوف قيم كمبيوتر. يحتاج منفّذ يدعم hookmetamethod.
-- ما يغيّر شي عند السيرفر، ويأثر فقط على سكربتات تقرأ القيم بعد تشغيله.
local spoofOn = false
local spoofInstalled = false

local function installSpoof()
	if spoofInstalled then return true end
	if type(hookmetamethod) ~= "function" or type(getnamecallmethod) ~= "function" then
		return false
	end
	local nc = type(newcclosure) == "function" and newcclosure or function(f) return f end
	local cc = type(checkcaller) == "function" and checkcaller or function() return false end
	local UIS = UserInputService
	local fake = {
		TouchEnabled = false,
		KeyboardEnabled = true,
		MouseEnabled = true,
		GamepadEnabled = false,
		AccelerometerEnabled = false,
		GyroscopeEnabled = false,
	}
	local ok = pcall(function()
		local oldIndex
		oldIndex = hookmetamethod(game, "__index", nc(function(self, key)
			if spoofOn and self == UIS and type(key) == "string" and fake[key] ~= nil and not cc() then
				return fake[key]
			end
			return oldIndex(self, key)
		end))
		local oldNamecall
		oldNamecall = hookmetamethod(game, "__namecall", nc(function(self, ...)
			if spoofOn and self == UIS and not cc() then
				local m = getnamecallmethod()
				if m == "GetPlatform" then
					return Enum.Platform.Windows
				elseif m == "GetLastInputType" then
					return Enum.UserInputType.MouseMovement
				end
			end
			return oldNamecall(self, ...)
		end))
	end)
	spoofInstalled = ok
	return ok
end

local function buildPCMode(size)
	local b = newButton(spoofOn and "PC ✓" or "PC", size)
	b.TextSize = 20
	b.BackgroundColor3 = spoofOn and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(40, 40, 40)
	b.Activated:Connect(function()
		if editMode then return end
		if not spoofOn and not installSpoof() then
			b.Text = "PC ✗"
			task.delay(2, function()
				if b.Parent then b.Text = spoofOn and "PC ✓" or "PC" end
			end)
			return
		end
		spoofOn = not spoofOn
		b.Text = spoofOn and "PC ✓" or "PC"
		b.BackgroundColor3 = spoofOn and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(40, 40, 40)
	end)
	return b
end

-- ========== كتالوج الأزرار ==========
local GROUP_MOUSE, GROUP_KEYS, GROUP_TOOLS = "ماوس", "كيبورد", "أدوات"
local catalog, catalogById = {}, {}

local function addSpec(spec)
	table.insert(catalog, spec)
	catalogById[spec.id] = spec
end

-- ماوس
addSpec({ id = "LClick", title = "كليك يسار", label = "Click", group = GROUP_MOUSE, size = Vector2.new(90, 90),
	build = function(s) return buildMouseButton(s.label, s.size, 0) end })
addSpec({ id = "LClickPlain", title = "كليك يسار (إضافي)", label = "L.Click", group = GROUP_MOUSE, size = Vector2.new(80, 60),
	build = function(s) return buildMouseButton(s.label, s.size, 0) end })
addSpec({ id = "RClick", title = "كليك يمين (يحرك الكاميرا)", label = "RClick", group = GROUP_MOUSE, size = Vector2.new(80, 80),
	build = function(s) return buildMouseButton(s.label, s.size, 1) end })
addSpec({ id = "RClickPlain", title = "كليك يمين عادي (بدون كاميرا)", label = "R.Click", group = GROUP_MOUSE, size = Vector2.new(80, 60),
	build = function(s) return buildMouseButton(s.label, s.size, 1, true) end })
addSpec({ id = "MClick", title = "كليك وسط", label = "MClick", group = GROUP_MOUSE, size = Vector2.new(80, 60),
	build = function(s) return buildMouseButton(s.label, s.size, 2) end })
addSpec({ id = "ZoomIn", title = "عجلة الماوس للأمام (زوم +)", label = "▲", group = GROUP_MOUSE, size = Vector2.new(56, 40),
	build = function(s) return buildScrollButton(s.label, s.size, true) end })
addSpec({ id = "ZoomOut", title = "عجلة الماوس للخلف (زوم -)", label = "▼", group = GROUP_MOUSE, size = Vector2.new(56, 40),
	build = function(s) return buildScrollButton(s.label, s.size, false) end })

-- كيبورد
local function keySpec(id, title, label, keycode, w, h)
	addSpec({ id = id, title = title, label = label, group = GROUP_KEYS, size = Vector2.new(w or 56, h or 56),
		build = function(s) return buildKeyButton(s.label, s.size, keycode) end })
end

keySpec("Space", "Space (قفز)", "Space", "Space", 130, 65)
keySpec("Shift", "Shift", "Shift", "LeftShift")
keySpec("Ctrl", "Ctrl", "Ctrl", "LeftControl")
keySpec("Alt", "Alt", "Alt", "LeftAlt")
keySpec("Tab", "Tab", "Tab", "Tab")
keySpec("Enter", "Enter", "ENTER", "Return")
keySpec("Esc", "Esc", "ESC", "Escape")
keySpec("Backspace", "Backspace", "Back", "Backspace")
keySpec("Emote", "Emote (قائمة الإيموت)", "Emote", "Period")
keySpec("Slash", "/ (الشات)", "/", "Slash")
keySpec("Up", "سهم فوق", "↑", "Up")
keySpec("Down", "سهم تحت", "↓", "Down")
keySpec("Left", "سهم يسار", "←", "Left")
keySpec("Right", "سهم يمين", "→", "Right")
for c in string.gmatch("ABCDEFGHIJKLMNOPQRSTUVWXYZ", ".") do
	keySpec(c, c, c, c)
end
local digitNames = { "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Zero" }
for i, name in ipairs(digitNames) do
	local d = tostring(i % 10)
	keySpec(d, d, d, name)
end
for i = 1, 12 do
	keySpec("F" .. i, "F" .. i, "F" .. i, "F" .. i)
end

-- أدوات
addSpec({ id = "Joystick", title = "جويستك WASD", label = "Joystick", group = GROUP_TOOLS, size = Vector2.new(170, 170),
	build = function(s) return buildJoystick(s.size) end })
addSpec({ id = "DPad", title = "D-Pad (أسهم تحرك WASD)", label = "DPad", group = GROUP_TOOLS, size = Vector2.new(150, 150),
	build = function(s) return buildDPad(s.size) end })
addSpec({ id = "Aim", title = "Aim (تصويب: مؤشر بالنص + ADS)", label = "AIM", group = GROUP_TOOLS, size = Vector2.new(80, 50),
	build = function(s) return buildAim(s.size) end })
addSpec({ id = "PCMode", title = "وضع PC (تجريبي): تمويه نوع الجهاز", label = "PC", group = GROUP_TOOLS, size = Vector2.new(70, 44),
	build = function(s) return buildPCMode(s.size) end })
addSpec({ id = "ShiftLock", title = "زر الهدف (Shift Lock)", label = "ShiftLock", group = GROUP_TOOLS, size = Vector2.new(70, 70),
	build = function(s) return buildShiftLock(s.size) end })
addSpec({ id = "MouseLock", title = "قفل / فتح الماوس", label = "MouseLock", group = GROUP_TOOLS, size = Vector2.new(120, 40),
	build = function(s) return buildMouseLock(s.size) end })
addSpec({ id = "TouchMode", title = "وضع اللمس (مباشر / تراك باد)", label = "TouchMode", group = GROUP_TOOLS, size = Vector2.new(120, 40),
	build = function(s) return buildTouchMode(s.size) end })
addSpec({ id = "Unstick", title = "فك التعليق", label = "Unstick", group = GROUP_TOOLS, size = Vector2.new(120, 40),
	build = function(s) return buildUnstick(s.size) end })

-- ========== إدارة الأزرار (إضافة / إزالة / سحب) ==========
local removeElement, refreshRow, selectElement, hideSizeBar
local selectedId = nil
local autoCount = 0
local function autoPos()
	local k = autoCount
	autoCount += 1
	return 0.30 + (k % 6) * 0.07, 0.30 + (math.floor(k / 6) % 4) * 0.14
end

local dragState = nil

local function attachDrag(id, obj)
	obj.InputBegan:Connect(function(input)
		if not editMode or not isPress(input) then return end
		if editKind == "calib" then return end
		if editKind == "delete" then
			-- وضع الحذف: اضغط على الزر يتحذف
			removeElement(id)
			refreshRow(id)
			saveState()
			return
		end
		if dragState then return end
		selectElement(id)
		dragState = {
			id = id,
			obj = obj,
			input = input,
			off = Vector2.new(input.Position.X, input.Position.Y) - obj.AbsolutePosition,
		}
	end)
end

UserInputService.InputChanged:Connect(function(input)
	if not dragState or input ~= dragState.input then return end
	local obj = dragState.obj
	if not obj.Parent then
		dragState = nil
		return
	end
	local vp = gui.AbsoluteSize
	local size = obj.AbsoluteSize
	local p = Vector2.new(input.Position.X, input.Position.Y) - dragState.off
	p = Vector2.new(
		math.clamp(p.X, 0, math.max(vp.X - size.X, 0)),
		math.clamp(p.Y, 0, math.max(vp.Y - size.Y, 0))
	)
	obj.Position = UDim2.new(p.X / vp.X, 0, p.Y / vp.Y, 0)
end)

UserInputService.InputEnded:Connect(function(input)
	if dragState and input == dragState.input then
		local obj = dragState.obj
		if obj.Parent then
			state.pos[dragState.id] = { x = obj.Position.X.Scale, y = obj.Position.Y.Scale }
			saveState()
		end
		dragState = nil
	end
end)

-- حجم كل زر: s = تكبير/تصغير، w = تمديد العرض، h = تمديد الطول
local function sizingOf(id)
	local z = state.sizes[id]
	if type(z) ~= "table" then return 1, 1, 1 end
	return tonumber(z.s) or 1, tonumber(z.w) or 1, tonumber(z.h) or 1
end

local function applySizing(id, obj, sc)
	local spec = catalogById[id]
	if not spec then return end
	local z, w, h = sizingOf(id)
	if id == "Joystick" then w, h = 1, 1 end -- الجويستك يبقى دايري
	obj.Size = UDim2.fromOffset(spec.size.X * w, spec.size.Y * h)
	sc.Scale = state.scale * z
end

local function spawnElement(id)
	if active[id] then return end
	local spec = catalogById[id]
	if not spec then return end

	local obj = spec.build(spec)

	local pos = state.pos[id]
	if type(pos) ~= "table" or type(pos.x) ~= "number" or type(pos.y) ~= "number" then
		local d = DEFAULT_POS[id]
		if d then
			pos = { x = d[1], y = d[2] }
		else
			local x, y = autoPos()
			pos = { x = x, y = y }
		end
		state.pos[id] = pos
	end

	obj.AnchorPoint = Vector2.new(0, 0)
	obj.Position = UDim2.new(pos.x, 0, pos.y, 0)

	local sc = Instance.new("UIScale")
	sc.Scale = state.scale
	sc.Parent = obj
	applySizing(id, obj, sc)

	-- إطار أصفر يظهر في وضع التعديل
	local stroke = Instance.new("UIStroke")
	stroke.Name = "EditStroke"
	stroke.Color = Color3.fromRGB(255, 210, 0)
	stroke.Thickness = 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Enabled = editMode
	stroke.Parent = obj

	attachDrag(id, obj)

	active[id] = { obj = obj, scale = sc, stroke = stroke }
	state.enabled[id] = true
end

function removeElement(id)
	local e = active[id]
	if not e then return end
	if selectedId == id then hideSizeBar() end
	releaseBtn(e.obj)
	active[id] = nil
	e.obj:Destroy()
	state.enabled[id] = false
end

-- ========== واجهة الإعدادات (زر واحد يتحكم بكل شي) ==========
local panel = Instance.new("Frame")
panel.Name = "Settings"
panel.Size = UDim2.new(0, 340, 1, -70)
panel.Position = UDim2.new(0.5, -170, 0, 56)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
panel.BackgroundTransparency = 0.08
panel.Active = true
panel.Visible = false
panel.ZIndex = 20
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local gear = newButton("⚙ الإعدادات", Vector2.new(120, 40))
gear.Name = "SettingsToggle"
gear.Position = UDim2.new(0.5, -60, 0, 8)
gear.ZIndex = 21
gear.BackgroundTransparency = 0.1

local doneBtn = newButton("✓ تم", Vector2.new(230, 40))
doneBtn.Name = "EditDone"
doneBtn.Position = UDim2.new(0.5, -115, 0, 8)
doneBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
doneBtn.ZIndex = 21
doneBtn.BackgroundTransparency = 0.1
doneBtn.Visible = false

-- تبويبات
local function styleTab(btn, selected)
	btn.BackgroundColor3 = selected and Color3.fromRGB(0, 120, 200) or Color3.fromRGB(55, 55, 55)
end

local tabGeneral = Instance.new("TextButton")
tabGeneral.Size = UDim2.new(1 / 3, -8, 0, 32)
tabGeneral.Position = UDim2.new(0, 6, 0, 8)
tabGeneral.Text = "عام"
tabGeneral.Font = Enum.Font.SourceSansBold
tabGeneral.TextSize = 18
tabGeneral.TextColor3 = Color3.new(1, 1, 1)
tabGeneral.AutoButtonColor = false
tabGeneral.Selectable = false
tabGeneral.Parent = panel
Instance.new("UICorner", tabGeneral).CornerRadius = UDim.new(0, 6)

local tabButtons = tabGeneral:Clone()
tabButtons.Position = UDim2.new(1 / 3, 6, 0, 8)
tabButtons.Text = "الأزرار"
tabButtons.Parent = panel

local tabShift = tabGeneral:Clone()
tabShift.Position = UDim2.new(2 / 3, 6, 0, 8)
tabShift.Text = "Shift Lock"
tabShift.Parent = panel

local generalFrame = Instance.new("Frame")
generalFrame.Size = UDim2.new(1, -16, 1, -52)
generalFrame.Position = UDim2.new(0, 8, 0, 48)
generalFrame.BackgroundTransparency = 1
generalFrame.Parent = panel

local buttonsFrame = Instance.new("ScrollingFrame")
buttonsFrame.Size = UDim2.new(1, -16, 1, -52)
buttonsFrame.Position = UDim2.new(0, 8, 0, 48)
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.BorderSizePixel = 0
buttonsFrame.ScrollBarThickness = 4
buttonsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
buttonsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
buttonsFrame.Visible = false
buttonsFrame.Parent = panel

local shiftFrame = Instance.new("ScrollingFrame")
shiftFrame.Size = UDim2.new(1, -16, 1, -52)
shiftFrame.Position = UDim2.new(0, 8, 0, 48)
shiftFrame.BackgroundTransparency = 1
shiftFrame.BorderSizePixel = 0
shiftFrame.ScrollBarThickness = 4
shiftFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
shiftFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
shiftFrame.Visible = false
shiftFrame.Parent = panel

local function showTab(name)
	generalFrame.Visible = (name == "general")
	buttonsFrame.Visible = (name == "buttons")
	shiftFrame.Visible = (name == "shift")
	styleTab(tabGeneral, name == "general")
	styleTab(tabButtons, name == "buttons")
	styleTab(tabShift, name == "shift")
end
tabGeneral.Activated:Connect(function() showTab("general") end)
tabButtons.Activated:Connect(function() showTab("buttons") end)
tabShift.Activated:Connect(function() showTab("shift") end)
showTab("general")

-- صفوف إعدادات Shift Lock
do
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = shiftFrame

	local order = 0
	local function row(labelText)
		order += 1
		local r = Instance.new("Frame")
		r.Size = UDim2.new(1, -8, 0, 38)
		r.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		r.BackgroundTransparency = 0.3
		r.LayoutOrder = order
		r.Parent = shiftFrame
		Instance.new("UICorner", r).CornerRadius = UDim.new(0, 6)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.new(1, -130, 1, 0)
		l.Position = UDim2.fromOffset(8, 0)
		l.BackgroundTransparency = 1
		l.Text = labelText
		l.TextColor3 = Color3.new(1, 1, 1)
		l.Font = Enum.Font.SourceSans
		l.TextSize = 16
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextTruncate = Enum.TextTruncate.AtEnd
		l.Parent = r
		return r
	end

	local function smallButton(parent, text, x, w)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(w, 28)
		b.Position = UDim2.new(1, x, 0.5, -14)
		b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
		b.Text = text
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.SourceSansBold
		b.TextSize = 18
		b.AutoButtonColor = false
		b.Selectable = false
		b.Parent = parent
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		return b
	end

	local function toggle(labelText, key)
		local b = smallButton(row(labelText), "", -98, 90)
		local function refresh()
			b.Text = SL[key] and "ON" or "OFF"
			b.BackgroundColor3 = SL[key] and Color3.fromRGB(40, 140, 70) or Color3.fromRGB(170, 50, 50)
		end
		refresh()
		b.Activated:Connect(function()
			SL[key] = not SL[key]
			refresh()
			saveState()
		end)
	end

	local function stepper(labelText, key, minV, maxV, step)
		local r = row(labelText)
		local minus = smallButton(r, "-", -124, 28)
		local plus = smallButton(r, "+", -36, 28)
		local val = Instance.new("TextLabel")
		val.Size = UDim2.fromOffset(52, 28)
		val.Position = UDim2.new(1, -94, 0.5, -14)
		val.BackgroundTransparency = 1
		val.TextColor3 = Color3.new(1, 1, 1)
		val.Font = Enum.Font.SourceSansBold
		val.TextSize = 16
		val.Parent = r
		local function refresh() val.Text = tostring(SL[key]) end
		refresh()
		local function change(d)
			SL[key] = math.floor(math.clamp(SL[key] + d, minV, maxV) * 100 + 0.5) / 100
			refresh()
			saveState()
		end
		minus.Activated:Connect(function() change(-step) end)
		plus.Activated:Connect(function() change(step) end)
	end

	toggle("Smooth camera", "Smooth")
	toggle("See through walls", "SeeThrough")
	toggle("Vibrate when ON", "Vibrate")
	stepper("Vibration strength", "VibrationStrength", 0.1, 1, 0.1)
	stepper("Vibration time (s)", "VibrationTime", 0.05, 1, 0.05)
	stepper("Shoulder offset", "Offset", -5, 5, 0.25)
	stepper("Aim offset", "AimOffset", 0, 3, 0.05)
	stepper("Aim zoom (FOV x)", "AimZoom", 0.4, 1, 0.05)

	local tr = row("Test vibration")
	local testBtn = smallButton(tr, "Test", -98, 90)
	testBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
	testBtn.Activated:Connect(function() vibrate(true) end)
end

-- سلايدر
local function createSlider(parent, label, minV, maxV, startV, yPos, decimals, onChange)
	local holder = Instance.new("Frame")
	holder.Size = UDim2.new(1, 0, 0, 42)
	holder.Position = UDim2.new(0, 0, 0, yPos)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 0, 18)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.SourceSansBold
	text.TextSize = 16
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Parent = holder

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -20, 0, 8)
	track.Position = UDim2.new(0, 10, 0, 28)
	track.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	track.BorderSizePixel = 0
	track.Parent = holder

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.Parent = track

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 20)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function setValue(v)
		local mult = 10 ^ decimals
		v = math.floor(math.clamp(v, minV, maxV) * mult + 0.5) / mult
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		text.Text = label .. ": " .. v
		onChange(v)
	end

	local dragInput
	local function updateFrom(input)
		local a = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(minV + (maxV - minV) * a)
	end

	holder.InputBegan:Connect(function(input)
		if isPress(input) and not dragInput then
			dragInput = input
			updateFrom(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragInput and input == dragInput then
			updateFrom(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput then dragInput = nil end
	end)

	setValue(startV)
end

createSlider(generalFrame, "FOV", 30, 120, state.fov, 0, 0, function(v)
	currentFOV = v
	state.fov = v
	saveState()
end)
createSlider(generalFrame, "Sensitivity", 0.1, 3, state.sens, 46, 1, function(v)
	state.sens = v
	applySens(v)
	saveState()
end)
createSlider(generalFrame, "Size", 0.5, 2, state.scale, 92, 1, function(v)
	state.scale = v
	for id, e in pairs(active) do
		local z = sizingOf(id)
		e.scale.Scale = v * z
	end
	saveState()
end)

-- ========== معايرة يدوية للمؤشر ==========
-- دائرة حمراء في منتصف الشاشة، والمؤشر الحقيقي يتحرك معاها؛ اضبطه بالأسهم لين يلمس مركزها
local calUI = Instance.new("Frame")
calUI.Name = "CalibrationUI"
calUI.Size = UDim2.new(0, 340, 0, 156)
calUI.Position = UDim2.new(0.5, -170, 1, -170)
calUI.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
calUI.BackgroundTransparency = 0.1
calUI.Active = true
calUI.Visible = false
calUI.ZIndex = 25
calUI.Parent = gui
Instance.new("UICorner", calUI).CornerRadius = UDim.new(0, 10)

local calTarget = Instance.new("Frame")
calTarget.Name = "CalTarget"
calTarget.Size = UDim2.fromOffset(28, 28)
calTarget.AnchorPoint = Vector2.new(0.5, 0.5)
calTarget.BackgroundTransparency = 1
calTarget.Visible = false
calTarget.ZIndex = 24
calTarget.Parent = gui
Instance.new("UICorner", calTarget).CornerRadius = UDim.new(1, 0)
local ringStroke = Instance.new("UIStroke", calTarget)
ringStroke.Color = Color3.fromRGB(255, 60, 60)
ringStroke.Thickness = 3
local ringDot = Instance.new("Frame")
ringDot.Size = UDim2.fromOffset(4, 4)
ringDot.AnchorPoint = Vector2.new(0.5, 0.5)
ringDot.Position = UDim2.new(0.5, 0, 0.5, 0)
ringDot.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
ringDot.BorderSizePixel = 0
ringDot.Parent = calTarget

local calTitle = Instance.new("TextLabel")
calTitle.Size = UDim2.new(1, -16, 0, 22)
calTitle.Position = UDim2.fromOffset(8, 6)
calTitle.BackgroundTransparency = 1
calTitle.Text = "حرّك المؤشر الحقيقي بالأسهم لين طرفه يلمس مركز الدائرة"
calTitle.TextColor3 = Color3.new(1, 1, 1)
calTitle.Font = Enum.Font.SourceSansBold
calTitle.TextSize = 15
calTitle.TextWrapped = true
calTitle.Parent = calUI

local calInfo = Instance.new("TextLabel")
calInfo.Size = UDim2.new(1, -16, 0, 18)
calInfo.Position = UDim2.fromOffset(8, 132)
calInfo.BackgroundTransparency = 1
calInfo.TextColor3 = Color3.fromRGB(180, 180, 180)
calInfo.Font = Enum.Font.SourceSans
calInfo.TextSize = 14
calInfo.Parent = calUI

local function calButton(text, x, y, w, h)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(w, h)
	b.Position = UDim2.fromOffset(x, y)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 20
	b.AutoButtonColor = false
	b.Selectable = false
	b.Parent = calUI
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local calLeft = calButton("◀", 8, 34, 60, 42)
local calUp = calButton("▲", 74, 34, 60, 42)
local calDown = calButton("▼", 140, 34, 60, 42)
local calRight = calButton("▶", 206, 34, 60, 42)
local calStepBtn = calButton("5", 272, 34, 60, 42)
local calSave = calButton("✓ حفظ", 8, 84, 150, 42)
calSave.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
local calZero = calButton("↺ صفر", 164, 84, 80, 42)
local calCancel = calButton("✕ إلغاء", 250, 84, 82, 42)
calCancel.BackgroundColor3 = Color3.fromRGB(180, 50, 50)

local calActive = false
local calStep = 5
local calPrev = Vector2.zero
local calConn = nil

local function showCalOffset()
	calInfo.Text = string.format("الإزاحة: %d , %d   |   الخطوة: %d بكسل (اضغط الرقم للتغيير)", calOffset.X, calOffset.Y, calStep)
end

local function exitCalibration(save)
	if not calActive then return end
	calActive = false
	if calConn then
		calConn:Disconnect()
		calConn = nil
	end
	if save then
		state.cal = { x = calOffset.X, y = calOffset.Y }
		saveState()
	else
		calOffset = calPrev
	end
	calUI.Visible = false
	calTarget.Visible = false
	editMode = false
	editKind = "move"
	gear.Visible = true
end

local function enterCalibration()
	if calActive then return end
	calActive = true
	calPrev = calOffset
	panel.Visible = false
	gear.Visible = false
	releaseAll()
	editMode = true
	editKind = "calib"

	local cam = Workspace.CurrentCamera
	local target = cam.ViewportSize / 2
	virtualCursor = target
	local o = probe.AbsolutePosition
	calTarget.Position = UDim2.fromOffset(target.X - o.X, target.Y - o.Y)
	calTarget.Visible = true
	calUI.Visible = true
	showCalOffset()

	-- نرسل المؤشر الحقيقي لمنتصف الشاشة كل إطار (مع الإزاحة الحالية)
	calConn = RunService.RenderStepped:Connect(function()
		sendMove(target)
	end)
end

local function nudge(dx, dy)
	calOffset = calOffset + Vector2.new(dx * calStep, dy * calStep)
	showCalOffset()
end
calLeft.Activated:Connect(function() nudge(-1, 0) end)
calRight.Activated:Connect(function() nudge(1, 0) end)
calUp.Activated:Connect(function() nudge(0, -1) end)
calDown.Activated:Connect(function() nudge(0, 1) end)
calStepBtn.Activated:Connect(function()
	calStep = (calStep == 1) and 5 or ((calStep == 5) and 20 or 1)
	calStepBtn.Text = tostring(calStep)
	showCalOffset()
end)
calZero.Activated:Connect(function()
	calOffset = Vector2.zero
	showCalOffset()
end)
calSave.Activated:Connect(function() exitCalibration(true) end)
calCancel.Activated:Connect(function() exitCalibration(false) end)

-- ========== شريط تكبير / تمديد الأزرار (يظهر في وضع التعديل لما تضغط زر) ==========
do
	local bar = Instance.new("Frame")
	bar.Name = "SizeBar"
	bar.Size = UDim2.fromOffset(372, 134)
	bar.Position = UDim2.new(0.5, -186, 0, 56)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	bar.BackgroundTransparency = 0.08
	bar.Active = true
	bar.Visible = false
	bar.ZIndex = 26
	bar.Parent = gui
	Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 10)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromOffset(356, 20)
	title.Position = UDim2.fromOffset(8, 4)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.SourceSansBold
	title.TextSize = 14
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.ZIndex = 27
	title.Parent = bar

	local function mk(text, x, y, w, h, color)
		local b = Instance.new("TextButton")
		b.Size = UDim2.fromOffset(w, h)
		b.Position = UDim2.fromOffset(x, y)
		b.BackgroundColor3 = color or Color3.fromRGB(60, 60, 60)
		b.Text = text
		b.TextColor3 = Color3.new(1, 1, 1)
		b.Font = Enum.Font.SourceSansBold
		b.TextSize = 20
		b.AutoButtonColor = false
		b.Selectable = false
		b.ZIndex = 27
		b.Parent = bar
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		return b
	end

	local function label(text, x)
		local l = Instance.new("TextLabel")
		l.Size = UDim2.fromOffset(88, 18)
		l.Position = UDim2.fromOffset(x, 26)
		l.BackgroundTransparency = 1
		l.Text = text
		l.TextColor3 = Color3.fromRGB(190, 190, 190)
		l.Font = Enum.Font.SourceSans
		l.TextSize = 14
		l.ZIndex = 27
		l.Parent = bar
	end

	local function info()
		if not selectedId then
			title.Text = ""
			return
		end
		local z, w, h = sizingOf(selectedId)
		local spec = catalogById[selectedId]
		title.Text = string.format("%s   |   حجم %.1f   عرض %.1f   طول %.1f",
			spec and spec.title or selectedId, z, w, h)
	end

	local function applySelected()
		local e = selectedId and active[selectedId]
		if e then applySizing(selectedId, e.obj, e.scale) end
		info()
		saveState()
	end

	-- field: "s" تكبير | "w" تمديد العرض | "h" تمديد الطول
	local function nudge(field, d)
		if not selectedId then return end
		if selectedId == "Joystick" and field ~= "s" then return end
		local z = state.sizes[selectedId]
		if type(z) ~= "table" then
			z = { s = 1, w = 1, h = 1 }
			state.sizes[selectedId] = z
		end
		z[field] = math.floor(math.clamp((tonumber(z[field]) or 1) + d, 0.4, 3) * 100 + 0.5) / 100
		applySelected()
	end

	-- تكبير/تصغير كل الأزرار مرة وحدة
	local function nudgeAll(d)
		state.scale = math.floor(math.clamp(state.scale + d, 0.5, 2) * 100 + 0.5) / 100
		for id, e in pairs(active) do
			local z = sizingOf(id)
			e.scale.Scale = state.scale * z
		end
		saveState()
	end

	local groups = {
		{ "الحجم", function(d) nudge("s", d) end },
		{ "العرض ↔", function(d) nudge("w", d) end },
		{ "الطول ↕", function(d) nudge("h", d) end },
		{ "كل الأزرار", nudgeAll },
	}
	for i, g in ipairs(groups) do
		local x = 8 + (i - 1) * 91
		label(g[1], x)
		local minus = mk("−", x, 46, 42, 34)
		local plus = mk("+", x + 46, 46, 42, 34)
		minus.Activated:Connect(function() g[2](-0.1) end)
		plus.Activated:Connect(function() g[2](0.1) end)
	end

	local reset = mk("↺ إعادة حجم هذا الزر", 8, 90, 356, 36, Color3.fromRGB(170, 50, 50))
	reset.Activated:Connect(function()
		if not selectedId then return end
		state.sizes[selectedId] = nil
		applySelected()
	end)

	function selectElement(id)
		selectedId = id
		for eid, e in pairs(active) do
			e.stroke.Color = (eid == id) and Color3.fromRGB(60, 220, 120) or Color3.fromRGB(255, 210, 0)
		end
		bar.Visible = true
		info()
	end

	function hideSizeBar()
		selectedId = nil
		bar.Visible = false
		for _, e in pairs(active) do
			e.stroke.Color = Color3.fromRGB(255, 210, 0)
		end
	end
end

-- أزرار الإعدادات العامة
local function panelButton(parent, text, yPos)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 36)
	b.Position = UDim2.new(0, 0, 0, yPos)
	b.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	b.Text = text
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.SourceSansBold
	b.TextSize = 18
	b.AutoButtonColor = false
	b.Selectable = false
	b.Parent = parent
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	return b
end

local editBtn = panelButton(generalFrame, "✎ تعديل الأماكن", 142)
editBtn.Size = UDim2.new(0.5, -3, 0, 36)
editBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
local deleteBtn = panelButton(generalFrame, "🗑 حذف الأزرار", 142)
deleteBtn.Size = UDim2.new(0.5, -3, 0, 36)
deleteBtn.Position = UDim2.new(0.5, 3, 0, 142)
deleteBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
local resetBtn = panelButton(generalFrame, "↺ إعادة الأماكن والأزرار الافتراضية", 186)
local calBtn = panelButton(generalFrame, "◎ معايرة تلقائية", 230)
calBtn.Size = UDim2.new(0.5, -3, 0, 36)
calBtn.Activated:Connect(function()
	calBtn.Text = "… جاري المعايرة"
	task.spawn(function()
		local ok = calibrateCursor()
		if ok then
			state.cal = { x = calOffset.X, y = calOffset.Y }
			saveState()
		end
		calBtn.Text = ok and "✓ تمت" or "✗ فشلت (جرّب اليدوية)"
		task.wait(2.5)
		calBtn.Text = "◎ معايرة تلقائية"
	end)
end)

local calManualBtn = panelButton(generalFrame, "✋ معايرة يدوية", 230)
calManualBtn.Size = UDim2.new(0.5, -3, 0, 36)
calManualBtn.Position = UDim2.new(0.5, 3, 0, 230)
calManualBtn.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
calManualBtn.Activated:Connect(enterCalibration)

-- وضع التعديل: اسحب أي زر لمكانه ثم اضغط "تم"
local function setEditMode(on, kind)
	editMode = on
	editKind = kind or "move"
	releaseAll()
	dragState = nil
	hideSizeBar()
	local color = (editKind == "delete") and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 210, 0)
	for _, e in pairs(active) do
		e.stroke.Color = color
		e.stroke.Enabled = on
	end
	doneBtn.Text = (editKind == "delete") and "✓ تم (اضغط زر لحذفه)" or "✓ تم (اسحب أو اضغط زر)"
	doneBtn.BackgroundColor3 = (editKind == "delete") and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(40, 140, 70)
	if on then
		panel.Visible = false
	end
	gear.Visible = not on
	doneBtn.Visible = on
end

gear.Activated:Connect(function()
	if editMode then return end
	panel.Visible = not panel.Visible
end)

editBtn.Activated:Connect(function()
	setEditMode(true, "move")
end)

deleteBtn.Activated:Connect(function()
	setEditMode(true, "delete")
end)

doneBtn.Activated:Connect(function()
	setEditMode(false)
	saveState()
end)

-- تبويب الأزرار: قائمة بكل أزرار الماوس والكيبورد والأدوات
local rowButtons = {}

function refreshRow(id)
	local b = rowButtons[id]
	if not b then return end
	if active[id] then
		b.Text = "✓ مضاف"
		b.BackgroundColor3 = Color3.fromRGB(40, 140, 70)
	else
		b.Text = "+ إضافة"
		b.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	end
end

do
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = buttonsFrame

	local order = 0
	for _, group in ipairs({ GROUP_MOUSE, GROUP_KEYS, GROUP_TOOLS }) do
		order += 1
		local header = Instance.new("TextLabel")
		header.Size = UDim2.new(1, -8, 0, 26)
		header.BackgroundTransparency = 1
		header.Text = "— " .. group .. " —"
		header.TextColor3 = Color3.fromRGB(0, 170, 255)
		header.Font = Enum.Font.SourceSansBold
		header.TextSize = 18
		header.LayoutOrder = order
		header.Parent = buttonsFrame

		for _, spec in ipairs(catalog) do
			if spec.group == group then
				order += 1
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, -8, 0, 34)
				row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				row.BackgroundTransparency = 0.3
				row.LayoutOrder = order
				row.Parent = buttonsFrame
				Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(1, -104, 1, 0)
				name.Position = UDim2.new(0, 8, 0, 0)
				name.BackgroundTransparency = 1
				name.Text = spec.title
				name.TextColor3 = Color3.new(1, 1, 1)
				name.Font = Enum.Font.SourceSans
				name.TextSize = 16
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.TextTruncate = Enum.TextTruncate.AtEnd
				name.Parent = row

				local toggle = Instance.new("TextButton")
				toggle.Size = UDim2.new(0, 90, 0, 26)
				toggle.Position = UDim2.new(1, -96, 0.5, -13)
				toggle.TextColor3 = Color3.new(1, 1, 1)
				toggle.Font = Enum.Font.SourceSansBold
				toggle.TextSize = 16
				toggle.AutoButtonColor = false
				toggle.Selectable = false
				toggle.Parent = row
				Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 6)

				rowButtons[spec.id] = toggle
				toggle.Activated:Connect(function()
					if active[spec.id] then
						removeElement(spec.id)
					else
						spawnElement(spec.id)
					end
					refreshRow(spec.id)
					saveState()
				end)
			end
		end
	end
end

-- إعادة الافتراضي
resetBtn.Activated:Connect(function()
	for id in pairs(active) do
		removeElement(id)
	end
	state.pos = {}
	state.sizes = {}
	state.enabled = {}
	autoCount = 0
	for _, id in ipairs(DEFAULT_ENABLED) do
		state.enabled[id] = true
	end
	for _, spec in ipairs(catalog) do
		if state.enabled[spec.id] then
			spawnElement(spec.id)
		end
		refreshRow(spec.id)
	end
	saveState()
end)

-- نضبط ZIndex لكل محتويات اللوحة عشان ما تختفي تحت خلفيتها (كانت تطلع معتمة)
local function applyZ(inst, z)
	for _, child in ipairs(inst:GetChildren()) do
		if child:IsA("GuiObject") then
			child.ZIndex = z + 1
			applyZ(child, z + 1)
		end
	end
end
applyZ(panel, panel.ZIndex)
applyZ(calUI, calUI.ZIndex)
applyZ(calTarget, calTarget.ZIndex)

-- ========== تشغيل: إنشاء الأزرار المحفوظة ==========
for _, spec in ipairs(catalog) do
	if state.enabled[spec.id] then
		spawnElement(spec.id)
	end
	refreshRow(spec.id)
end

-- منع تحديد الأزرار (Selection)
pcall(function() GuiService.AutoSelectGuiEnabled = false end)

if CONFIG.PC_MODE_AT_START and installSpoof() then
	spoofOn = true
end

task.spawn(function()
	task.wait(1.5)
	if not state.cal and calibrateCursor() then
		state.cal = { x = calOffset.X, y = calOffset.Y }
		saveState()
	end
end)
