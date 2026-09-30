const { app, BrowserWindow, dialog } = require('electron')
const path = require('path')

function createWindow() {
  const win = new BrowserWindow({
    width: 1440,
    height: 900,
    minWidth: 1000,
    minHeight: 650,
    title: 'TENΛ Budget',
    backgroundColor: '#0b0f19',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true
    }
  })

  const page = path.resolve(__dirname, '../mobile/dist/index.html')
  console.log('TENΛ Budget →', page)

  win.loadFile(page).catch(error => {
    console.error(error)
    dialog.showErrorBox('TENΛ Budget — erreur', String(error))
  })

  win.webContents.on('did-fail-load', (_event, code, description) => {
    dialog.showErrorBox(
      'TENΛ Budget — erreur de chargement',
      `Code : ${code}\n\n${description}\n\nFichier :\n${page}`
    )
  })
}

app.whenReady().then(createWindow)

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})
