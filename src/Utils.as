string GetRandomIcon(const string &in hash) {
    auto icons = Icons::GetAll();
    auto iconKeys = icons.GetKeys();
    if (hash.Length < 16) throw("Hash must be at least 16 hex characters long.");
    auto n = Text::ParseUInt(hash.SubStr(4, 4), 16);
    return string(icons[iconKeys[n % iconKeys.Length]]);
}

void Notify(const string &in message) {
    UI::ShowNotification(PluginName, message, 5000);
}

void NotifySuccess(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(.4, .7, .1, .3), 10000);
    print("Notified Success: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

void Dev_NotifyWarning(const string &in msg) {
    warn(msg);
#if SIG_DEVELOPER
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 8000);
#endif
}

void Dev_Notify(const string &in msg) {
#if DEV
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    print("Notified: " + msg);
#endif
}

void dev_trace(const string &in msg) {
#if SIG_DEVELOPER
    trace(msg);
#endif
}
