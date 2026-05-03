-- Upscaler.app
-- Drop image files on the icon (or onto the app in Finder/Dock).
-- Choose a scale factor and an output folder. Each image is upscaled and
-- saved as <name>_x<scale>.png in the chosen folder.

on open dropped_items
    -- Filter to image files only
    set image_files to {}
    repeat with itm in dropped_items
        set p to POSIX path of itm
        set ext to my lower(my file_ext(p))
        if ext is in {"png", "jpg", "jpeg", "webp"} then
            set end of image_files to p
        end if
    end repeat

    if (count of image_files) is 0 then
        display dialog "No supported images found. Drop PNG, JPEG, or WebP files." buttons {"OK"} default button "OK" with icon caution
        return
    end if

    -- Ask scale
    set n to count of image_files
    set scale_choice to button returned of (display dialog ¬
        "Upscale " & n & " image" & my plural(n) & " by:" ¬
        buttons {"2x", "3x", "4x"} default button "4x" with title "Upscaler")
    set scale to text 1 of scale_choice

    -- Ask output folder
    set output_folder to choose folder with prompt "Choose a folder to save the upscaled images."
    set output_path to POSIX path of output_folder

    -- Locate bundled engine
    set bundle_path to POSIX path of (path to me)
    set engine to bundle_path & "Contents/Resources/engine/upscayl-bin"
    set models to bundle_path & "Contents/Resources/engine/models"

    -- Process each file
    set total to count of image_files
    set failures to {}
    repeat with i from 1 to total
        set src to item i of image_files
        try
            set base to do shell script "f=" & quoted form of src & "; b=$(basename \"$f\"); echo \"${b%.*}\""
            set dest to output_path & base & "_x" & scale & ".png"
            do shell script ¬
                quoted form of engine & ¬
                " -i " & quoted form of src & ¬
                " -o " & quoted form of dest & ¬
                " -s " & scale & ¬
                " -n realesrgan-x4plus" & ¬
                " -m " & quoted form of models & ¬
                " -f png" & ¬
                " 2>&1"
        on error errMsg
            set end of failures to (src & ": " & errMsg)
        end try
    end repeat

    if (count of failures) is 0 then
        display notification "Upscaled " & total & " image" & my plural(total) & ¬
            " to " & output_path ¬
            with title "Upscaler" sound name "Glass"
    else
        set msg to "Done with " & ((total - (count of failures)) as string) & ¬
            " of " & total & " images.\n\nFailures:\n"
        repeat with f in failures
            set msg to msg & f & "\n"
        end repeat
        display dialog msg buttons {"OK"} default button "OK" with icon caution
    end if
end open

-- Allow launching by double-click (no files dropped) -> picker
on run
    set picked to choose file with prompt "Choose images to upscale" of type {"png", "jpg", "jpeg", "webp"} with multiple selections allowed
    open picked
end run

-- Helpers
on file_ext(p)
    set AppleScript's text item delimiters to "."
    set parts to text items of p
    set AppleScript's text item delimiters to ""
    if (count of parts) < 2 then return ""
    return last item of parts
end file_ext

on lower(s)
    return do shell script "printf '%s' " & quoted form of s & " | tr '[:upper:]' '[:lower:]'"
end lower

on plural(n)
    if n is 1 then
        return ""
    else
        return "s"
    end if
end plural
