var THEME_KEYS = [
  "amethyst_accent_color",
  "amethyst_bg_color",
  "amethyst_card_bg_color",
  "amethyst_sidebar_bg_color",
  "amethyst_topbar_bg_color",
  "amethyst_rightpanel_bg_color",
  "amethyst_text_color",
  "amethyst_secondary_text_color",
  "amethyst_ui_border_color"
];

var PRESETS = {
  amethyst: {
    background: "#0b0714",
    accent: "#a98bff",
    text: "#f7f3ff",
    secondary: "#b9aecf",
    card: "#171124",
    sidebar: "#120d1e",
    topbar: "#171124",
    rightpanel: "#120d1e",
    border: "#3a2b5c"
  },
  midnight: {
    background: "#05080f",
    accent: "#4da3ff",
    text: "#eef6ff",
    secondary: "#a9bdd4",
    card: "#0e1624",
    sidebar: "#0a111d",
    topbar: "#0e1624",
    rightpanel: "#0a111d",
    border: "#23384f"
  },
  cyberpunk: {
    background: "#0a0014",
    accent: "#ff2bd6",
    text: "#fdf0ff",
    secondary: "#d3a8e8",
    card: "#1a0628",
    sidebar: "#13041f",
    topbar: "#1a0628",
    rightpanel: "#13041f",
    border: "#ff2bd6"
  },
  forest: {
    background: "#06100a",
    accent: "#4ade80",
    text: "#effff4",
    secondary: "#a8cbb4",
    card: "#0f1f15",
    sidebar: "#0b1710",
    topbar: "#0f1f15",
    rightpanel: "#0b1710",
    border: "#2f5c40"
  },
  daylight: {
    background: "#f4f1fb",
    accent: "#6d4aff",
    text: "#171122",
    secondary: "#5f5875",
    card: "#ffffff",
    sidebar: "#ece7f7",
    topbar: "#ffffff",
    rightpanel: "#ece7f7",
    border: "#d8d0ea"
  }
};

function setting(key, fallback) {
  var value = Witch.getSetting(key, fallback);
  if (value === null || value === undefined) return fallback;
  return value;
}

function asBool(value) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  var text = String(value).toLowerCase();
  return text === "true" || text === "1" || text === "yes";
}

function clamp(value, min, max) {
  var number = Number(value);
  if (!isFinite(number)) return min;
  if (number < min) return min;
  if (number > max) return max;
  return number;
}

function parseColor(value) {
  if (typeof value !== "string") return null;
  var text = value.trim();
  if (text.charAt(0) === "#") text = text.substring(1);
  if (text.length !== 6 && text.length !== 8) return null;
  if (!/^[0-9a-fA-F]+$/.test(text)) return null;
  return {
    r: parseInt(text.substring(0, 2), 16),
    g: parseInt(text.substring(2, 4), 16),
    b: parseInt(text.substring(4, 6), 16)
  };
}

function hex(channel) {
  var value = Math.max(0, Math.min(255, Math.round(channel)));
  return (value < 16 ? "0" : "") + value.toString(16);
}

function toHex(color) {
  return "#" + hex(color.r) + hex(color.g) + hex(color.b);
}

function mix(from, to, amount) {
  var a = parseColor(from);
  var b = parseColor(to);
  if (!a || !b) return from;
  var t = clamp(amount, 0, 1);
  return toHex({
    r: a.r + (b.r - a.r) * t,
    g: a.g + (b.g - a.g) * t,
    b: a.b + (b.b - a.b) * t
  });
}

function luminance(value) {
  var color = parseColor(value);
  if (!color) return 0;
  var r = color.r / 255;
  var g = color.g / 255;
  var b = color.b / 255;
  r = r <= 0.03928 ? r / 12.92 : Math.pow((r + 0.055) / 1.055, 2.4);
  g = g <= 0.03928 ? g / 12.92 : Math.pow((g + 0.055) / 1.055, 2.4);
  b = b <= 0.03928 ? b / 12.92 : Math.pow((b + 0.055) / 1.055, 2.4);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function chooseColor(value, fallback) {
  if (typeof value !== "string" || value === "auto" || !parseColor(value)) return fallback;
  return value;
}

function applyTheme(key, value) {
  Witch.setThemeColor(key, value);
}

function clearTheme() {
  for (var i = 0; i < THEME_KEYS.length; i++) {
    Witch.setThemeColor(THEME_KEYS[i], "");
  }
}

function main() {
  if (!asBool(setting("master", true))) {
    clearTheme();
    return;
  }

  var presetName = String(setting("preset", "amethyst"));
  var preset = PRESETS[presetName] || PRESETS.amethyst;
  var background = chooseColor(setting("background", "auto"), preset.background);
  var accent = chooseColor(setting("accent", "auto"), preset.accent);
  var depth = clamp(setting("depth", 0.35), 0, 1);
  var contrast = asBool(setting("contrast", false));
  var glow = asBool(setting("glow", true));
  var tone = String(setting("textTone", "auto"));

  background = mix(background, "#000000", depth * (luminance(background) > 0.55 ? 0.22 : 0.5));

  var text;
  if (tone === "light") text = "#f7f3ff";
  else if (tone === "dark") text = "#171122";
  else text = luminance(background) > 0.55 ? "#171122" : "#f7f3ff";

  var secondary = mix(text, background, contrast ? 0.28 : 0.42);
  var card = mix(background, text, contrast ? 0.12 : 0.08);
  var sidebar = mix(background, text, contrast ? 0.07 : 0.045);
  var topbar = mix(background, text, contrast ? 0.09 : 0.06);
  var rightpanel = mix(background, text, contrast ? 0.08 : 0.05);
  var border = glow ? accent : mix(background, text, contrast ? 0.38 : 0.28);

  applyTheme("amethyst_accent_color", accent);
  applyTheme("amethyst_bg_color", background);
  applyTheme("amethyst_card_bg_color", card);
  applyTheme("amethyst_sidebar_bg_color", sidebar);
  applyTheme("amethyst_topbar_bg_color", topbar);
  applyTheme("amethyst_rightpanel_bg_color", rightpanel);
  applyTheme("amethyst_text_color", text);
  applyTheme("amethyst_secondary_text_color", secondary);
  applyTheme("amethyst_ui_border_color", border);
  Witch.reloadTheme();
  Witch.log("Theme Studio applied " + presetName);
}

main();
