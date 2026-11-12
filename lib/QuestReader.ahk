; Polar, Bucko and Riley publish quest state only after a complete, consistent read.
nm_ReadQuest(giver, quests) {
    nm_setShiftLock(0)
    nm_OpenMenu("questlog")
    try {
        reader := QuestReader(giver, quests)
        result := reader.Read()
        if result.state = "unreadable"
            nm_setStatus("Quest", giver " quest could not be read" ((reader.why != "") ? " (" reader.why ", see tools\OCR_debug\quest_fail.png)" : ""))
        return result
    } catch as err {
        nm_setStatus("Quest", giver " quest could not be read: " err.Message)
        return {state: "unreadable"}
    }
}

class QuestReader {
    __New(giver, quests) {
        this.images := Map(), this.bitmap := 0, this.quests := quests, this.why := "", this.dumped := 0, this.lastTitleText := "nothing"
        this.markers := giver = "Polar" ? ["polar_bear", "polar_bear2", "polar_bear3"]
            : giver = "Bucko" ? ["bucko", "bucko2"] : ["riley", "riley2"]
        this.giverName := giver = "Polar" ? "Polar Bear" : giver = "Bucko" ? "Bucko Bee" : "Riley Bee"
        this.hwnd := GetRobloxHWND()
        GetRobloxClientPos(this.hwnd)
        this.width := windowWidth, this.height := windowHeight
        this.top := GetYOffset(this.hwnd) + 150, this.bottom := this.height - 20
        if this.width < 350 || this.bottom - this.top < 200
            throw Error("Quest panel is too small")
    }

    __Delete() {
        if this.HasOwnProp("bitmap") && this.bitmap
            Gdip_DisposeImage(this.bitmap)
        if this.HasOwnProp("images")
            for name, bitmap in this.images
                Gdip_DisposeImage(bitmap)
    }

    Capture() {
        global bitmaps
        if !this.hwnd || !WinActive("ahk_id " this.hwnd)
            throw Error("Roblox is not active")
        GetRobloxClientPos(this.hwnd)
        if windowWidth != this.width || windowHeight != this.height
            throw Error("Roblox was resized")
        MouseMove windowX + 350, windowY + GetYOffset(this.hwnd) + 100
        if this.bitmap
            Gdip_DisposeImage(this.bitmap), this.bitmap := 0
        this.bitmap := Gdip_BitmapFromScreen(windowX "|" windowY "|310|" this.height)
        if !this.bitmap
            throw Error("Quest capture failed")
        if Gdip_ImageSearch(this.bitmap, bitmaps["questlog"], , 0, this.top - 78, 310, this.top + 2, 2) != 1
            throw Error("Quest panel is not open")
    }

    Find(name, top, bottom, variation := 5) {
        if !this.images.Has(name) {
            bitmap := Gdip_CreateBitmapFromFile(A_WorkingDir "\nm_image_assets\" name ".png")
            if !bitmap
                throw Error("Missing quest image: " name)
            this.images[name] := bitmap
        }
        top := Max(this.top, top), bottom := Min(this.bottom, bottom)
        if bottom <= top
            return 0
        result := Gdip_ImageSearch(this.bitmap, this.images[name], &point, 0, top, 306, bottom, variation)
        if result < 0
            throw Error("Quest image search failed")
        if result = 1 {
            xy := StrSplit(point, ",")
            return {x: xy[1] + 0, y: xy[2] + 0}
        }
        return 0
    }

    ReadPage() {
        global QuestBarSize, QuestBarGapSize, QuestBarInset
        ; Roblox font update: the giver-name and quest-title pictures are text in the old font, so OCR is
        ; tried first and the pictures are only a fallback (the bar-gap picture is a graphic and still works)
        marker := this.OCRMarker()
        if !marker
            for name in this.markers {
                marker := this.Find(name, this.top, this.bottom, 50)
                if marker
                    break
            }
        if !marker
            return {state: "missing"}
        gap := marker.HasOwnProp("ocr") ? this.Find("questbargap", marker.y - 10, marker.y + 60)
            : this.Find("questbargap", marker.y, marker.y + 45)
        if !gap
            return this.Fail("no quest bar under the " (marker.HasOwnProp("ocr") ? "OCR'd" : "pictured") " name at y=" marker.y)
        title := this.OCRTitle(gap.y)
        if (title = "")
        for variation in [5, 10, 25, 50, 100] {
            matches := []
            for name in this.quests
                if this.Find(name, gap.y - 30, gap.y, variation)
                    matches.Push(name)
            if matches.Length > 1
                return this.Fail("title pictures matched several quests")
            if matches.Length = 1 {
                title := matches[1]
                break
            }
        }
        if title = ""
            return this.Fail("quest title not recognised (OCR read: " this.lastTitleText ")")
        rows := [], incomplete := false
        for objective in this.quests[title] {
            y := gap.y + QuestBarSize * (objective[1] - 1)
            if y < this.top || y + QuestBarSize > this.bottom
                return {state: "clipped"}
            rowGap := this.Find("questbargap", y, y + QuestBarGapSize)
            if !rowGap || Abs(rowGap.y - y) > 2
                return this.Fail(title ": objective " objective[1] " bar not where expected (y=" y (rowGap ? ", found at " rowGap.y : ", none found") ")")
            samples := []
            for dy in [5, 20, 34]
                samples.Push(Gdip_GetPixel(this.bitmap, QuestBarInset + 6, rowGap.y + QuestBarGapSize + dy) & 0xFFFFFF)
            state := this.Classify(samples)
            if state = "unreadable" {
                ; the quest panel is see-through, so in a field the bar's exact shade shifts with whatever is
                ; behind it (seen: 69D465 to 95EB7A for one bar). Then go by colour type instead, and look at the
                ; right end of the bar too: a finished bar is green all the way, an unfinished one is still red there
                right := []
                for dy in [5, 20, 34]
                    right.Push(Gdip_GetPixel(this.bitmap, QuestBarInset + 262, rowGap.y + QuestBarGapSize + dy) & 0xFFFFFF) ; bars end ~271 px in
                state := this.ClassifyByHue(samples, right)
                if state = "unreadable"
                    return this.Fail(title ": objective " objective[1] " (" objective[2] " " objective[3] ") bar colour unknown: left "
                        . Format("{:06X} {:06X} {:06X}", samples*) ", right " Format("{:06X} {:06X} {:06X}", right*))
            }
            rows.Push(state)
            incomplete := incomplete || state = "incomplete"
        }
        return {state: "ready", title: title, rows: rows, incomplete: incomplete}
    }

    ; OCR: line with the quest giver's name (or, failing that, one of this giver's quest titles)
    OCRMarker() {
        global windowX, windowY
        if (found := nm_OCRMatchNames([this.giverName], 0, this.top, 310, this.bottom - this.top, windowX, windowY))
            return {x: found[2], y: found[3], ocr: 1}
        names := []
        for name in this.quests
            names.Push(name)
        if (found := nm_OCRMatchNames(names, 0, this.top, 310, this.bottom - this.top, windowX, windowY))
            return {x: found[2], y: found[3], ocr: 1}
        return 0
    }

    ; OCR: quest title in the 30 px title bar above the first objective bar
    OCRTitle(gapY) {
        global windowX, windowY
        names := []
        for name in this.quests
            names.Push(name)
        if (found := nm_OCRMatchNames(names, 0, gapY - 30, 306, 30, windowX, windowY))
            return names[found[1]]
        ; for the failure note: what OCR saw in the title bar
        this.lastTitleText := "nothing"
        try {
            pPart := Gdip_CloneBitmapArea(this.bitmap, 0, Max(0, gapY - 30), 306, 30)
            if (r := nm_OCR_FromBitmap(pPart, 2, 0)) && (Trim(r.Text) != "")
                this.lastTitleText := "'" Trim(r.Text) "'"
            Gdip_DisposeImage(pPart)
        }
        return ""
    }

    ; records why this page couldn't be read (shown in the status message) and, the first time per read, saves
    ; the quest panel picture and the reason to tools\OCR_debug\quest_fail.png / .txt
    Fail(why) {
        this.why := why
        if !this.dumped && this.bitmap {
            this.dumped := 1
            try {
                dir := nm_OCR_RootDir() "\tools\OCR_debug"
                DirCreate dir
                Gdip_SaveBitmapToFile(this.bitmap, dir "\quest_fail.png")
                FileOpen(dir "\quest_fail.txt", "w").Write(FormatTime(, "yyyy-MM-dd HH:mm:ss") "  " this.giverName "`n" why "`n"
                    . "panel top " this.top ", bottom " this.bottom ", window " this.width "x" this.height "`n")
            }
        }
        return {state: "unreadable"}
    }

    static Classify(samples) {
        complete := 0, incomplete := 0
        for color in samples {
            if this.Near(color, 0xF46C55, 8) || this.Near(color, 0x6EFF60, 8)
                incomplete += 1
            else if this.Near(color, 0x8BF48B, 12) || this.Near(color, 0x6FD18C, 12) ; 6FD18C: current complete colour
                complete += 1
        }
        if incomplete >= 2 && !complete
            return "incomplete"
        if complete >= 2 && !incomplete
            return "complete"
        return "unreadable"
    }

    Classify(samples) => QuestReader.Classify(samples)

    ; "green", "red" or "" for one pixel, by which colour clearly dominates (works through the see-through panel)
    static Hue(color) {
        r := (color >> 16) & 255, g := (color >> 8) & 255, b := color & 255
        if (g >= r + 30) && (g >= b + 30)
            return "green"
        if (r >= g + 50) && (r >= b + 50)
            return "red"
        return ""
    }
    ; most of the 3 pixels share a colour type: that type, else ""
    static Majority(samples) {
        greens := 0, reds := 0
        for color in samples
            (h := this.Hue(color)) = "green" ? greens++ : (h = "red") ? reds++ : 0
        return (greens >= 2) ? "green" : (reds >= 2) ? "red" : ""
    }
    ; left: pixels at the start of the bar, right: pixels near its end. Red at the start = not started; green at the
    ; start = started, and then the end decides: green = complete, red = still in progress
    static ClassifyByHue(left, right) {
        l := this.Majority(left)
        if (l = "red")
            return "incomplete"
        if (l = "green") {
            r := this.Majority(right)
            return (r = "green") ? "complete" : (r = "red") ? "incomplete" : "unreadable"
        }
        return "unreadable"
    }
    ClassifyByHue(left, right) => QuestReader.ClassifyByHue(left, right)

    static Near(color, expected, tolerance) {
        for shift in [0, 8, 16]
            if Abs(((color >> shift) & 255) - ((expected >> shift) & 255)) > tolerance
                return false
        return true
    }

    Confirm(result) {
        Sleep 120
        this.Capture()
        next := this.ReadPage()
        if next.state != "ready" || next.title != result.title || next.rows.Length != result.rows.Length
            return (next.state = "unreadable") ? next : this.Fail(result.title ": second read didn't match the first (" next.state ")")
        for i, state in result.rows
            if state != next.rows[i]
                return this.Fail(result.title ": objective " i " read " state " then " next.rows[i])
        return next
    }

    Scroll(direction) {
        global QuestBarInset, QuestBarGapSize, QuestBarSize
        gap := this.Find("questbargap", this.top, this.bottom - QuestBarSize)
        if !gap {
            this.ScrollInput(direction)
            return true
        }
        y := gap.y + QuestBarGapSize, height := QuestBarSize - QuestBarGapSize
        before := Gdip_CloneBitmapArea(this.bitmap, QuestBarInset, y, 288, height)
        if !before
            throw Error("Quest scroll capture failed")
        try {
            this.ScrollInput(direction)
            after := Gdip_CloneBitmapArea(this.bitmap, QuestBarInset, y, 288, height)
            if !after
                throw Error("Quest scroll capture failed")
            try result := Gdip_ImageSearch(after, before)
            finally Gdip_DisposeImage(after)
            if result < 0
                throw Error("Quest scroll comparison failed")
            return result != 1
        } finally Gdip_DisposeImage(before)
    }

    ScrollInput(direction) {
        GetRobloxClientPos(this.hwnd)
        MouseMove windowX + 30, windowY + this.top + 50
        Sleep 50
        SendEvent "{Wheel" direction "}"
        Sleep 200
        this.Capture()
    }

    Read() {
        this.Capture()
        Loop 2 {
            result := this.ReadPage()
            if result.state = "ready" {
                confirmed := this.Confirm(result)
                if confirmed.state = "ready"
                    return confirmed
            } else {
                Sleep 120
                this.Capture()
            }
        }
        if GetKeyState("F14")
            return {state: "unreadable"}
        stable := 0
        Loop 100 {
            stable := this.Scroll("Up") ? 0 : stable + 1
            result := this.ReadPage()
            if result.state = "ready" {
                confirmed := this.Confirm(result)
                if confirmed.state = "ready"
                    return confirmed
            }
            if stable >= 2
                break
        }
        reachedTop := stable >= 2
        stable := 0, sawQuest := false
        Loop 150 {
            result := this.ReadPage()
            sawQuest := sawQuest || result.state != "missing"
            if result.state = "ready" {
                confirmed := this.Confirm(result)
                if confirmed.state = "ready"
                    return confirmed
            }
            if stable >= 2 {
                if (this.why = "")
                    this.why := !sawQuest ? this.giverName " not found in the quest log" (reachedTop ? "" : " (couldn't scroll to the top)") : "quest seen but never read fully"
                return {state: sawQuest || !reachedTop ? "unreadable" : "absent"}
            }
            stable := this.Scroll("Down") ? 0 : stable + 1
        }
        return {state: "unreadable"}
    }
}
