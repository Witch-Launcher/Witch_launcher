const greeting = Witch.getSetting("greeting", "Hello from Witch!");
const accent = Witch.getSetting("accent", "#7c5cff");

Witch.log(greeting + " Plugin " + Witch.pluginID + " v" + Witch.version);
Witch.setThemeColor("amethyst_accent_color", accent);
