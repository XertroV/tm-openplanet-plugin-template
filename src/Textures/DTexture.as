// source: https://github.com/XertroV/tm-openplanet-plugin-template/edit/master/src/Textures/DTexture.as (which is Public Domain)

const string OPENPLANET_STORAGE_FOLDER = IO::FromStorageFolder("");

const vec4 cRed75 = vec4(1.0, 0.1, 0.1, 0.75);
const vec4 cGreen75 = vec4(0.1, 1.0, 0.1, 0.75);
const vec4 cBlack50 = vec4(0.0, 0.0, 0.0, 0.5);

/*
    Example texture helper class for loading saved images. Path should be relative to the storage folder, or absolute somewhere in the user OpenplanetNext folder.

    Note: use TextureCache::GetURL to load from a URL.

    Safe to declare as a global variable -- it will wait for the texture file to become available if it doesn't exist yet.

    ### Usage

    ```asc
    auto tex = DTexture("example.png"); // path auto-converted to storage folder via IO::FromStorageFolder.
    // if using nvg (after you have done nvg::Begin, and nvg::Rect, etc). shows a gradient if the texture is not loaded yet.
    nvg::FillPaint(this.GetPaint(origin, size, 0.0));
    bool nvgTexIsLoaded = tex.GetNvg() !is null;
    // if using UI, this will draw the image at native size and do nothing if the texture is not loaded yet.
    tex.UI_AddImage();
    bool uiTexIsLoaded = tex.GetUi() !is null;
    ```
*/
class DTexture {
    string path;
    bool fileExists;
    protected nvg::Texture@ tex;
    protected UI::Texture@ uiTex;
    vec2 dims;

    DTexture(const string &in path) {

        if (path.Length == 0) {
            Dev_NotifyWarning("DTexture: path cannot be empty");
            return;
        }

        this.path = path;
        if (!path.StartsWith(OPENPLANET_STORAGE_FOLDER)) {
            this.path = IO::FromStorageFolder(path);
        }
        startnew(CoroutineFunc(WaitForTexture));
    }

    void WaitForTextureSilent() {
        while (!IO::FileExists(path)) {
            yield();
        }
        yield();
    }

    void WaitForTexture() {
        dev_trace("waiting for texture: " + path);
        WaitForTextureSilent();
        dev_trace("Found texture: " + path);
        fileExists = true;
    }

    vec2 GetSize() {
        if (tex !is null) {
            return dims;
        }
        return vec2(60.);
    }

    nvg::Texture@ GetNvg() {
        if (tex !is null) {
            return tex;
        }
        if (!fileExists) {
            return null;
        }
        // We need to load the image form a buffer. So we read the file instead of using LoadTexture with the path.
        IO::File f(path, IO::FileMode::Read);
        @tex = nvg::LoadTexture(f.Read(f.Size()), nvg::TextureFlags::None);
        if (tex !is null) dims = tex.GetSize();
        return tex;
    }

    UI::Texture@ GetUi() {
        if (uiTex !is null) {
            return uiTex;
        }
        if (!fileExists) {
            return null;
        }
        IO::File f(path, IO::FileMode::Read);
        @uiTex = UI::LoadTexture(f.Read(f.Size()));
        if (uiTex !is null) dims = uiTex.GetSize();
        return uiTex;
    }

    nvg::Paint GetPaint(vec2 origin, vec2 size, float angle, float alpha = 1.0) {
        auto t = GetNvg();
        if (t is null) return nvg::LinearGradient(vec2(), g_screen, cRed75, cGreen75);
        return nvg::TexturePattern(origin, size, angle, t, alpha);
    }

    void NvgDrawImage(vec2 drawPos, vec2 drawSize = vec2(-1), vec2 drawOrigin = vec2(0), vec2 spritePos = vec2(0)) {
        auto t = GetNvg();
        if (t is null) return;
        if (drawSize.x < 0) drawSize = dims;
        drawPos -= drawOrigin;
        float nativeDir = 1.0; // 1.0 for normal, -1.0 for flipped

		auto rectSize = drawSize;
		bool flip = nativeDir < 0;
		if (flip) {
			// we scale X by -1 to flip; this adjusts positions to match
			drawPos.x = -drawSize.x - drawPos.x;
		}
		// vec4 uv = vec4(pos.x, pos.y, size.x, size.y);

		auto tform = nvg::CurrentTransform();
		nvg::Transform(mat3::Scale(vec2(nativeDir, 1)));

		nvg::ShapeAntiAlias(false);
		nvg::BeginPath();
		nvg::Rect(drawPos, rectSize);
		// nvg::StrokeWidth(4.0);
		// nvg::StrokeColor(vec4(1, 0, 0, 1));
		// nvg::Stroke();
		vec2 scale = rectSize / dims;
		auto paint = nvg::TexturePattern(drawPos - spritePos * scale, t.GetSize() * scale, 0, tex, 1.0);
		nvg::FillPaint(paint);
		nvg::Fill();
		nvg::ClosePath();

		nvg::SetTransform(tform);
	}

    void UI_AddImage(UI::DrawList@ dl = null, vec2 drawSize = vec2(-1), bool addDummy = true) {
        auto t = GetUi();
        if (t is null) return;
        if (dl is null) @dl = UI::GetWindowDrawList();
		drawSize = drawSize.x > 0 ? drawSize : dims;
		auto cur_pos = UI::GetWindowPos() + UI::GetCursorPos() - vec2(UI::GetScrollX(), UI::GetScrollY());
		vec4 uv = vec4(0, 0, dims.x, dims.y);
        bool flip = false;
		if (flip) {
			uv.x += dims.x;
			uv.z *= -1;
		}
		dl.AddImage(t, cur_pos, drawSize, 0xFFFFFFFF, uv);
        if (addDummy) UI::Dummy(drawSize);
	}

    // If the texture is a sprite sheet, this is an easy way to access a particular sprite.
    DTextureSprite@ GetSprite(nat2 topLeft, nat2 size) {
        return DTextureSprite(this, topLeft, size);
    }
}

// A simple way to use a sprite sheet.
class DTextureSprite : DTexture {
    vec2 topLeft;
    vec2 spriteSize;
    DTexture@ parent;

    DTextureSprite(DTexture@ tex, nat2 topLeft, nat2 size) {
        super("?nonexistant;*");
        this.topLeft.x = topLeft.x;
        this.topLeft.y = topLeft.y;
        this.spriteSize.x = size.x;
        this.spriteSize.y = size.y;
        @this.parent = tex;
    }

    void WaitForTextureSilent() override {
        parent.WaitForTextureSilent();
    }

    void WaitForTexture() override {
        parent.WaitForTextureSilent();
    }

    vec2 GetSize() override {
        return spriteSize;
    }

    nvg::Texture@ GetNvg() override {
        return parent.GetNvg();
    }

    UI::Texture@ GetUi() override {
        return parent.GetUi();
    }

    nvg::Paint GetPaint(vec2 origin, vec2 size, float angle, float alpha = 1.0) override {
        vec2 scale = size / spriteSize;
        auto t = parent.GetNvg();
        if (t is null) return nvg::LinearGradient(vec2(), g_screen, cGreen75, cRed75);
        return nvg::TexturePattern(origin - topLeft * scale, t.GetSize(), angle, t, alpha);
    }

    // spritePos unused in DTextureSprite
    void NvgDrawImage(vec2 drawPos, vec2 drawSize = vec2(-1), vec2 drawOrigin = vec2(0), vec2 spritePos = vec2(0)) override {
        DTexture::NvgDrawImage(drawPos, drawSize, drawOrigin, topLeft);
    }

	void UI_AddImage(UI::DrawList@ dl = null, vec2 drawSize = vec2(-1), bool addDummy = true) override {
        auto t = GetUi();
        if (t is null) return;
        if (dl is null) @dl = UI::GetWindowDrawList();
		drawSize = drawSize.x > 0 ? drawSize : spriteSize;
		auto cur_pos = UI::GetWindowPos() + UI::GetCursorPos() - vec2(UI::GetScrollX(), UI::GetScrollY());
		vec4 uv = vec4(topLeft.x, topLeft.y, spriteSize.x, spriteSize.y);
        bool flip = false;
		if (flip) {
			uv.x += spriteSize.x;
			uv.z *= -1;
		}
		dl.AddImage(t, cur_pos, drawSize, 0xFFFFFFFF, uv);
        if (addDummy) UI::Dummy(drawSize);
	}
}
