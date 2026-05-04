-- Upscaler.app
-- Drop a single image, multiple images, or whole folders onto the icon.
-- Folders are walked recursively for .png / .jpg / .jpeg / .webp files.
-- A real progress window shows current image and overall progress.

use AppleScript version "2.4"
use framework "Foundation"
use framework "AppKit"
use scripting additions

property progressWin : missing value
property progressBar : missing value
property progressLabel : missing value
property statusLabel : missing value

on open dropped_items
    my processItems(dropped_items)
end open

-- Double-click launch -> ask whether to pick files or a folder
on run
    try
        set choice to button returned of (display dialog ¬
            "What do you want to upscale?" & return & return & ¬
            "(You can also drag images or a folder directly onto the app icon.)" ¬
            buttons {"Cancel", "Folder", "Images"} default button "Images" ¬
            cancel button "Cancel" with title "Upscaler")
    on error number -128
        return
    end try
    if choice is "Folder" then
        try
            set folder_choice to choose folder with prompt ¬
                "Choose a folder. All images inside (and in subfolders) will be upscaled."
        on error number -128
            return
        end try
        my processItems({folder_choice})
    else
        try
            set picked to choose file with prompt "Choose images to upscale." ¬
                of type {"public.image"} with multiple selections allowed
        on error number -128
            return
        end try
        my processItems(picked)
    end if
end run

-- The shared body of work, called from both on open and on run.
on processItems(items_list)
    try
        -- Expand: collect all image files (recursing into any folders)
        set image_files to my collectImages(items_list)
        set total to count of image_files

        if total is 0 then
            display dialog "No PNG, JPEG, or WebP images found in your selection." ¬
                buttons {"OK"} default button "OK" with icon caution with title "Upscaler"
            return
        end if

        -- Ask scale (3x default)
        set scale_choice to button returned of (display dialog ¬
            "Found " & total & " image" & my plural(total) & ". Upscale by:" & return & return & ¬
            "2x is fastest. 4x looks great but is much slower, especially on older Macs." ¬
            buttons {"2x", "3x", "4x"} default button "3x" with title "Upscaler")
        set scale to text 1 of scale_choice

        -- Ask output folder
        set output_folder to choose folder with prompt "Choose where to save the upscaled images."
        set output_path to POSIX path of output_folder

        -- Locate engine
        set bundle_path to POSIX path of (path to me)
        set engine to bundle_path & "Contents/Resources/engine/upscayl-bin"
        set models to bundle_path & "Contents/Resources/engine/models"

        -- Show real progress window (AppKit)
        my showProgressWindow(total)

        -- Process each image serially. nice + -t 100 + -j 1:1:1 keep the
        -- system responsive on weaker Macs.
        set failures to {}
        repeat with i from 1 to total
            set src to item i of image_files
            my updateProgress(i - 1, ¬
                "Image " & i & " of " & total & " (" & scale & "x)", ¬
                my basename(src))

            try
                set base to my stripExt(my basename(src))
                set dest to my uniqueDest(output_path, base, scale)
                with timeout of 3600 seconds
                    do shell script ¬
                        "nice -n 19 " & ¬
                        quoted form of engine & ¬
                        " -i " & quoted form of src & ¬
                        " -o " & quoted form of dest & ¬
                        " -s " & scale & ¬
                        " -n realesrgan-x4plus" & ¬
                        " -m " & quoted form of models & ¬
                        " -t 100" & ¬
                        " -j 1:1:1" & ¬
                        " -f png" & ¬
                        " 2>&1"
                end timeout
            on error errMsg
                copy (my basename(src) & ": " & errMsg) to end of failures
            end try
        end repeat

        my updateProgress(total, "Done", "")
        delay 0.4
        my closeProgressWindow()

        if (count of failures) is 0 then
            display notification "Upscaled " & total & " image" & my plural(total) & ¬
                " to " & output_path with title "Upscaler" sound name "Glass"
        else
            set msg to "Done. " & ((total - (count of failures)) as string) & ¬
                " of " & total & " succeeded." & return & return & "Failures:" & return
            repeat with f in failures
                set msg to msg & f & return
            end repeat
            display dialog msg buttons {"OK"} default button "OK" ¬
                with icon caution with title "Upscaler"
        end if
    on error errMsg number errNum
        try
            my closeProgressWindow()
        end try
        if errNum is -128 then return -- user cancelled, silent
        display dialog "Upscaler hit an error:" & return & return & errMsg & ¬
            return & return & "(error " & errNum & ")" ¬
            buttons {"OK"} default button "OK" with icon stop with title "Upscaler"
    end try
end processItems

-- Recursively collect image POSIX paths from a list of files and folders
on collectImages(items_list)
    set result to {}
    repeat with itm in items_list
        set p to POSIX path of (contents of itm)
        set isDir to false
        try
            set isDir to ((do shell script ¬
                "if [ -d " & quoted form of p & " ]; then echo y; else echo n; fi") is "y")
        end try
        if isDir then
            set found to ""
            try
                set found to do shell script ¬
                    "find " & quoted form of p & " -type f \\( " & ¬
                    "-iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp'" & ¬
                    " \\) | LC_ALL=C sort"
            end try
            if found is not "" then
                -- `paragraphs of` splits on CR, LF, or CRLF. `do shell script`
                -- returns CR-separated text on macOS, so plain text-item
                -- splitting with `linefeed` does NOT work.
                repeat with f in (paragraphs of found)
                    set fStr to (f as text)
                    if fStr is not "" then copy fStr to end of result
                end repeat
            end if
        else
            set ext to my lower(my file_ext(p))
            if ext is in {"png", "jpg", "jpeg", "webp"} then
                copy p to end of result
            end if
        end if
    end repeat
    return result
end collectImages

-- Real progress window via AppleScriptObjC
on showProgressWindow(total)
    set rect to current application's NSMakeRect(0, 0, 480, 130)
    set styleMask to (current application's NSWindowStyleMaskTitled)
    set progressWin to current application's NSWindow's alloc()'s ¬
        initWithContentRect:rect styleMask:styleMask ¬
        backing:(current application's NSBackingStoreBuffered) defer:false
    progressWin's setTitle:"Upscaler"
    progressWin's |center|()
    progressWin's setLevel:(current application's NSFloatingWindowLevel)

    set progressLabel to current application's NSTextField's alloc()'s ¬
        initWithFrame:(current application's NSMakeRect(20, 85, 440, 22))
    progressLabel's setStringValue:"Starting..."
    progressLabel's setBezeled:false
    progressLabel's setEditable:false
    progressLabel's setSelectable:false
    progressLabel's setBackgroundColor:(current application's NSColor's clearColor)
    progressLabel's setFont:(current application's NSFont's systemFontOfSize:13)
    (progressWin's contentView())'s addSubview:progressLabel

    set statusLabel to current application's NSTextField's alloc()'s ¬
        initWithFrame:(current application's NSMakeRect(20, 60, 440, 20))
    statusLabel's setStringValue:""
    statusLabel's setBezeled:false
    statusLabel's setEditable:false
    statusLabel's setSelectable:false
    statusLabel's setBackgroundColor:(current application's NSColor's clearColor)
    statusLabel's setFont:(current application's NSFont's systemFontOfSize:11)
    statusLabel's setTextColor:(current application's NSColor's secondaryLabelColor)
    (progressWin's contentView())'s addSubview:statusLabel

    set progressBar to current application's NSProgressIndicator's alloc()'s ¬
        initWithFrame:(current application's NSMakeRect(20, 25, 440, 20))
    progressBar's setIndeterminate:false
    progressBar's setMinValue:0
    progressBar's setMaxValue:total
    progressBar's setDoubleValue:0
    (progressWin's contentView())'s addSubview:progressBar

    progressWin's makeKeyAndOrderFront:(missing value)
    current application's NSApp's activateIgnoringOtherApps:true

    -- Dock badge progress as backup
    set progress total steps to total
    set progress completed steps to 0
    set progress description to "Upscaling " & total & " image" & my plural(total) & "..."
end showProgressWindow

on updateProgress(step, mainText, subText)
    if progressBar is not missing value then
        progressBar's setDoubleValue:step
        progressLabel's setStringValue:mainText
        statusLabel's setStringValue:subText
        -- Pump the run loop briefly so the window repaints between images
        current application's NSRunLoop's mainRunLoop()'s ¬
            runUntilDate:(current application's NSDate's dateWithTimeIntervalSinceNow:0.02)
    end if
    set progress completed steps to step
    set progress additional description to mainText
end updateProgress

on closeProgressWindow()
    if progressWin is not missing value then
        progressWin's orderOut:(missing value)
        set progressWin to missing value
        set progressBar to missing value
        set progressLabel to missing value
        set statusLabel to missing value
    end if
end closeProgressWindow

-- Helpers
on file_ext(p)
    set AppleScript's text item delimiters to "."
    set parts to text items of p
    set AppleScript's text item delimiters to ""
    if (count of parts) < 2 then return ""
    return last item of parts
end file_ext

on basename(p)
    set AppleScript's text item delimiters to "/"
    set parts to text items of p
    set AppleScript's text item delimiters to ""
    return last item of parts
end basename

on stripExt(name)
    set AppleScript's text item delimiters to "."
    set parts to text items of name
    set AppleScript's text item delimiters to ""
    if (count of parts) < 2 then return name
    set base to ""
    repeat with i from 1 to (count of parts) - 1
        if i > 1 then set base to base & "."
        set base to base & item i of parts
    end repeat
    return base
end stripExt

on lower(s)
    return do shell script "printf '%s' " & quoted form of s & " | tr '[:upper:]' '[:lower:]'"
end lower

on plural(n)
    if n is 1 then return ""
    return "s"
end plural

on uniqueDest(folder_path, base, scale)
    set candidate to folder_path & base & "_x" & scale & ".png"
    set i to 2
    repeat while (do shell script ¬
        "if [ -e " & quoted form of candidate & " ]; then echo y; else echo n; fi") is "y"
        set candidate to folder_path & base & "_x" & scale & "_" & i & ".png"
        set i to i + 1
        if i > 999 then exit repeat
    end repeat
    return candidate
end uniqueDest
