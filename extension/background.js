// 🔧 Ensure side panel behavior is set (runs on install/update)
chrome.runtime.onInstalled.addListener(() => {
    chrome.sidePanel.setPanelBehavior({
        openPanelOnActionClick: true
    });
});

// 🚀 Open side panel when extension icon is clicked
chrome.action.onClicked.addListener(async (tab) => {
    console.log("🟢 Extension clicked", tab);

    if (!tab?.id) {
        console.warn("⚠️ No tab ID found");
        return;
    }

    try {
        await chrome.sidePanel.open({ tabId: tab.id });
        console.log("✅ Side panel opened");
    } catch (err) {
        console.error("❌ Failed to open side panel:", err);
    }
});

// 👇 Listen for OAuth redirect and capture token
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
    // Only act when fully loaded
    if (changeInfo.status !== "complete" || !tab.url) return;

    // 🔒 Safer check (avoid false positives)
    if (!tab.url.includes("auth_token=")) return;

    try {
        const url = new URL(tab.url);
        const token = url.searchParams.get("auth_token");

        if (!token) {
            console.warn("⚠️ Token not found in URL");
            return;
        }

        console.log("✅ User logged in:", token);

        // Save token
        chrome.storage.local.set({ token }, () => {
            console.log("💾 Token saved");
        });

        // Notify UI (side panel / Flutter)
        chrome.runtime.sendMessage({
            type: "AUTH_SUCCESS",
            token
        });

        // Close OAuth tab safely
        if (tabId) {
            chrome.tabs.remove(tabId);
            console.log("🗑️ OAuth tab closed");
        }

    } catch (err) {
        console.error("❌ Error parsing OAuth redirect:", err);
    }
});