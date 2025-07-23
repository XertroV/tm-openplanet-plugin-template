namespace TextureCache {
    dictionary _textures;

    const string IMAGES_FOLDER = IO::FromStorageFolder("Images/");

    // Call this if you want to open the images directory quickly.
    void OpenImagesFolderInExplorer() {
        OpenExplorerPath(IMAGES_FOLDER);
    }

    // Get an image from a URL. Safe to call as many times as you want.
    DTexture@ GetURL(const string &in url, const string &in filename = "") {
        return MaybeDownloadImage(url, filename);
    }

    dictionary _downloads;

    DTexture@ MaybeDownloadImage(const string &in url, const string &in filename = "") {
        if (_textures.Exists(url)) {
            return cast<DTexture>(_textures[url]);
        }
        @_downloads[url] = DownloadTex(url, filename);
        auto tex = DTexture(IMAGES_FOLDER + filename);
        @_textures[url] = tex;
        return tex;
    }

    class DownloadTex {
        string url;
        string filename;
        string imageExt;
        bool done = false;

        DownloadTex(const string &in _url, const string &in _filename = "") {
            url = _url;
            filename = _filename;
            _DetectType();
            if (filename.Length == 0) {
                filename = Crypto::MD5(url) + ".jpg"; // default to MD5 hash of URL
            }
            startnew(CoroutineFunc(CheckFileAndStartIfAbsent));
        }

        void CheckFileAndStartIfAbsent() {
            if (!IO::FolderExists(IMAGES_FOLDER)) IO::CreateFolder(IMAGES_FOLDER);
            if (IO::FileExists(IMAGES_FOLDER + filename)) {
                OnDone();
                return;
            }
            startnew(CoroutineFunc(this.RunDownload));
        }

        void RunDownload() {
            dev_trace("Downloading texture: " + url);
            Net::HttpRequest@ req = Net::HttpRequest(url);
            // req.Start(); // If you aren't saving to file, use Start instead of StartToFile
            req.StartToFile(IMAGES_FOLDER + filename);
            // we should check .Finished() every frame.
            while (!req.Finished()) yield();
            // The request has finished. We can check the response code, response body, etc.
            auto respCode = req.ResponseCode();
            if (200 <= respCode && respCode < 300) {
                // we don't need to worry about saving anything if we used StartToFile instead of Start
                // dev_trace("Download successful: " + url);
                // req.SaveToFile(IMAGES_FOLDER + filename);
            } else {
                warn("[HTTP:" + respCode + "] Download failed: " + url + " (code: " + respCode + ") / Error: " + req.Error());
            }
            OnDone();
        }

        void OnDone() {
            done = true;
            dev_trace("Download completed: " + url);
            // Clean up this download so it gets garbage collected.
            if (_downloads.Exists(url)) {
                _downloads.Delete(url);
            }
        }

        void _DetectType() {
            if (filename.EndsWith(".png")) {
                imageExt = "png";
            } else if (filename.EndsWith(".jpg") || filename.EndsWith(".jpeg")) {
                imageExt = "jpg";
            } else if (url.EndsWith(".png")) {
                imageExt = "png";
            } else if (url.EndsWith(".jpg") || url.EndsWith(".jpeg")) {
                imageExt = "jpg";
            } else {
                imageExt = "jpg"; // default to jpg
            }
        }
    }
}
