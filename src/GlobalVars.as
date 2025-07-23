// update this at the top of the RenderEarly callback or similar
vec2 g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
// for if you need to scale UI:: calculations
float g_scale = UI::GetScale();

// Called before other render functions. Useful for updating global variables.
void RenderEarly() {
    g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    g_scale = UI::GetScale();
}
