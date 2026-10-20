const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('buddy', {
  bootstrap: () => ipcRenderer.invoke('bootstrap'),
  onState: (callback) => ipcRenderer.on('state', (_event, state) => callback(state)),
  onCommand: (callback) => ipcRenderer.on('command', (_event, command, value) => callback(command, value)),
  balance: () => ipcRenderer.invoke('balance'),
  menu: () => ipcRenderer.send('menu'),
  dragStart: (x, y) => ipcRenderer.send('drag-start', { x, y }),
  dragMove: (x, y) => ipcRenderer.send('drag-move', { x, y }),
  dragEnd: () => ipcRenderer.send('drag-end'),
  setHitRects: (rects) => ipcRenderer.send('hit-rects', rects),
  saveUi: (patch) => ipcRenderer.send('save-ui', patch),
});
