const string PluginName = Meta::ExecutingPlugin().Name;
const string PluginNameHash = Crypto::MD5(PluginName); // TODO: this isn't needed once you do the 2 below TODOs
const string MenuIconColor = "\\$" + PluginNameHash.SubStr(0, 3); // TODO: replace with "\\$f83" or whatever
const string PluginIcon = GetRandomIcon(PluginNameHash); // TODO: replace with a specific icon, e.g., Icons::Bath
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

// You should customize the template to your preference.

void Main() {
    print("Hello from " + PluginName);
}

void RenderMenu() {
    // Render this plugin's entry under the "Plugins" menu
    if (UI::MenuItem(MenuTitle, "", S_Enabled)) {
        Notify("Menu item clicked!");
        S_Enabled = !S_Enabled; // Toggle the setting
    }
}
