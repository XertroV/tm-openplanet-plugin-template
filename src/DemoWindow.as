
UI::Texture@ g_tex;

void _LoadTexture() {
    if (g_tex !is null) return;
    // This is for a texture that is included with the plugin.
    // See DTexture for loading textures from disk.
    @g_tex = UI::LoadTexture("test.jpg");
}

void RenderInterface() {
    if (!S_Enabled) return;

    // simple way to handle a texture
    if (g_tex is null) _LoadTexture();

    // UI::SetNextWindowSize(700, 400, UI::Cond::Appearing);
    UI::SetNextWindowSize(700, 400, UI::Cond::FirstUseEver);
    if (UI::Begin(MenuTitle, S_Enabled)) {
        // putting UI logic in separate functions makes it easy to `return` from them without worrying about needing to call UI::End() or similar.
        RenderWindowMain_Inner();
    }
    UI::End();
}

void RenderWindowMain_Inner() {
    auto plugin = Meta::ExecutingPlugin();
    UI::TextWrapped("Plugin Name: " + PluginName);
    UI::TextWrapped("Plugin Category: " + plugin.Category);
    UI::TextWrapped("Plugin Author: " + plugin.Author);

    UI::SeparatorText("Useful Info");
    UI::TextWrapped("This window will only appear if the openplanet overlay is showing. Use the `Render()` callback to render a window that always shows.");
    UI::TextWrapped("You can close this window because S_Enabled is passed as an argument. If no second argument is provided, the window will not have an [X] in the top right corner.");
    UI::TextWrapped("\\$8bf\\$i  Text with colors :) " + Icons::Bath);

    UI::SeparatorText("Simple Texture Example");
    if (g_tex is null) {
        UI::Text("Loading texture...");
    } else {
        UI::Image(g_tex, vec2(96, 64));
    }

    UI::SeparatorText("DTexture Example");
    DTexture@ texFromUrl = TextureCache::GetURL("https://assets.xk.io/d++/secret/generic.png", "example-img.png");
    if (texFromUrl is null) {
        // texFromUrl should never actually be null
        UI::Text("Loading texture...");
        return;
    } else {
        // calculate pos before UI_AddImage which will change the cursor pos
        auto nvgPos = UI::GetWindowPos() + UI::GetCursorPos() - vec2(30 + texFromUrl.GetSize().x, 0);
        // draw image via UI:: as well as a UI::Dummy() to match
        texFromUrl.UI_AddImage(UI::GetWindowDrawList());
        nvg::Reset();
        texFromUrl.NvgDrawImage(nvgPos);
        UI::TextWrapped("NVG image on left of window. UI image above.");
    }
}
