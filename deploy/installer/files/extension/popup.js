chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
  const tab = tabs[0];
  document.getElementById("url").textContent = tab && tab.url ? tab.url : "(no active tab)";
});
