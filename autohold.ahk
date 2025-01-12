#Requires AutoHotKey v2.0
#SingleInstance Force

SetKeyDelay -1
SendMode "Event"

hold_keys := []
pressing_keys := []
click_interval := 300
repeated_trigger := 3
SHIFT_BIT := 0x10000

class NameKey
{
    name := ""
    key := ""

    __New(name, key)
    {
        this.name := name
        this.key := key
    }
}

; SHIFT_BIT + sc is key
mouse_keys := Map(
    SHIFT_BIT + 0x24, NameKey("Mouse Left", "LButton"),
    SHIFT_BIT + 0x25, NameKey("Mouse Middle", "MButton"),
    SHIFT_BIT + 0x26, NameKey("Mouse Right", "RButton"),
    SHIFT_BIT + 0x7, NameKey("Mouse Button 4", "XButton1"),
    SHIFT_BIT + 0x8, NameKey("Mouse Button 5", "XButton2")
)

key_name(key)
{
    if mouse_keys.Has(key)
    {
        return StrTitle(mouse_keys[key].name)
    }
    else
    {
        return StrTitle(GetKeyName(Format("sc{:X}", key)))
    }
}

index_of(arr, key)
{
    for val in arr
    {
        if IsSet(val) && val == key
        {
            return A_Index
        }
    }

    return 0
}

stop_holding(key, name, pos, menu)
{
    menu.Delete(name)
    key_index := index_of(hold_keys, key)
    
    if key_index
    {
        if mouse_keys.Has(key)
        {
            Send "{" mouse_keys[key].key " Up}"
        }
        else
        {
            Send Format("{{}sc{:X} Up{}}", key)
        }

        hold_keys.Delete(key_index)
    }
}

on_key_down(key_menu, ih, vk_key, sc_key)
{
    Critical

    static last_key_tick := -1
    static last_key := -1
    static repeated := 0

    global hold_keys
    global pressing_keys

    if index_of(pressing_keys, sc_key)
    {
        return
    }

    pressing_keys.Push(sc_key)
    key := sc_key + (GetKeyState("Shift") ? SHIFT_BIT : 0)
    key_index := index_of(hold_keys, key)

    if key_index
    {
        if mouse_keys.Has(key)
        {
            Send "{" mouse_keys[key].key " Up}"
        }
        else
        {
            Send Format("{{}sc{:X} Up{}}", key)
        }

        key_menu.Delete(key_name(key))
        hold_keys.Delete(key_index)
        repeated := 0
        last_key := key
        last_key_tick := A_TickCount

        return
    }

    if last_key == key && A_TickCount - last_key_tick <= click_interval
    {
        repeated += 1

        if repeated >= repeated_trigger
        {
            hold_keys.Push(key)

            if mouse_keys.Has(key)
            {
                Send "{" mouse_keys[key].key " DownR}"
            }
            else
            {
                Send Format("{{}sc{:X} DownR{}}", key)
            }

            key_menu.Add(key_name(key), stop_holding.Bind(key))
            repeated := 0
        }
    }
    else
    {
        repeated := 1
        last_key := key
    }
    
    last_key_tick := A_TickCount
}

on_key_up(ih, vk_key, sc_key)
{
    Critical

    global pressing_keys

    if (index := index_of(pressing_keys, sc_key))
    {
        pressing_keys.Delete(index)
    }
}

dbg()
{
    global hold_keys

    dbg_message := "Keys"
    
    for key in hold_keys
    {
        if IsSet(key)
        {
            dbg_message .= Format("`n{:03X}", key)
        }
    }
}

switch_sendmode(name, pos, menu)
{
    static previous_mode := ""

    if name = "&Help"
    {
        MsgBox(
            "Input Mode is the method of simulating holding keys.`n"
            "Sometimes a game won't receive inputs in a particular input mode "
            "while another game might work with it. If you find the script "
            "doesn't work for a game, "
            "try switching to another mode.`n`n"
            "If all of them don't work, then unfortunately this script will "
            "never work for this game and you need other applications.`n`n"
            "By default the input mode is `"Event`".", 
            "Help"
        )

        return
    }

    SendMode SubStr(name, 2)
    
    if previous_mode
    {
        menu.ToggleCheck(previous_mode)
    }

    menu.ToggleCheck(name)
    previous_mode := name
}





input_mode_menu := Menu()

for input_mode in ["&Event", "&Input", "&Play", "&Help"]
{
    input_mode_menu.Add(input_mode, switch_sendmode)
}

switch_sendmode("&Event", 1, input_mode_menu)
holding_keys_menu := Menu()

A_TrayMenu.Add("Input Mode", input_mode_menu)
A_TrayMenu.Add("Held Keys", holding_keys_menu)
A_TrayMenu.Add("Help", (*) => MsgBox(
    "To start holding a key, repeatedly press the key 3 times.`n"
    "To stop holding a key, press that key again or`n"
    "select it in `"Held Keys`" in the menu.`n"
    "To hold mouse buttons, hold Shift and repeat the following keys:`n`n"
    "J => Left`n"
    "K => Middle`n"
    "L => Right`n"
    "U => Button 4`n"
    "I => Button 5`n`n"
    "Note game controllers might not work as I don't have one to test with.",
    "Help"
))

ih := InputHook("L0 B V E", "{BackSpace}")

ih.OnKeyDown := on_key_down.Bind(holding_keys_menu)
ih.OnKeyUp := on_key_up
ih.OnEnd := (*) => ExitApp
ih.KeyOpt("{All}", "+N")
ih.Start()

SetTimer dbg, 1000