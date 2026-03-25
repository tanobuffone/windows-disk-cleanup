# Disk Cleanup Tool for Windows 🧹

Herramienta completa para análisis, limpieza y mantenimiento automático del disco C: en Windows.

## 📁 Estructura del Proyecto

```
C:\DiskCleanupTool\
├── Analyze-Disk.ps1          # Análisis de uso de espacio
├── Clean-Disk.ps1            # Limpieza interactiva
├── Maintenance.ps1           # Mantenimiento automático diario
├── Setup-ScheduledTask.bat   # Configurador de tarea programada
└── README.md                 # Esta documentación
```

## 🚀 Instalación Rápida

1. **Copia la carpeta** a tu Windows (ej: `C:\DiskCleanupTool\`)

2. **Ejecuta el configurador** como Administrador:
   ```
   Clic derecho en Setup-ScheduledTask.bat → Ejecutar como administrador
   ```

3. **¡Listo!** La tarea programada se ejecutará automáticamente cada día a las 3:00 AM.

## 📊 Uso de los Scripts

### 1. Analyze-Disk.ps1 — Análisis de Disco

Genera un reporte detallado del uso de espacio en disco C:.

**Ejecución:**
```powershell
.\Analyze-Disk.ps1
```

**Parámetros opcionales:**
```powershell
.\Analyze-Disk.ps1 -TopFolders 30          # Mostrar top 30 carpetas
.\Analyze-Disk.ps1 -LargeFileThresholdMB 50 # Archivos > 50MB
```

**Salida:**
- Reporte HTML interactivo en `C:\DiskCleanup\Reports\`
- Archivo CSV con categorías limpiables
- Resumen en consola con barras de progreso

**Qué analiza:**
- ✅ Espacio total, usado y libre del disco
- ✅ Categorías de archivos limpiables (temporales, caché, logs)
- ✅ Top 20 carpetas más grandes
- ✅ Archivos grandes (>100MB)
- ✅ Caché de navegadores (Chrome, Edge, Firefox)

---

### 2. Clean-Disk.ps1 — Limpieza Interactiva

Permite seleccionar qué categorías limpiar de forma interactiva.

**Ejecución:**
```powershell
.\Clean-Disk.ps1                    # Modo interactivo
.\Clean-Disk.ps1 -Auto              # Modo automático (solo categorías seguras)
```

**Categorías disponibles:**
| # | Categoría | Seguro para Auto |
|---|-----------|------------------|
| 1 | 🗑️ Temporales de usuario (>7 días) | ✅ |
| 2 | 🗑️ Temporales de Windows (>7 días) | ✅ |
| 3 | 🌐 Caché de Chrome | ✅ |
| 4 | 🌐 Caché de Edge | ✅ |
| 5 | 🌐 Caché de Firefox | ✅ |
| 6 | 📥 Descargas (>30 días) | ❌ |
| 7 | 🗑️ Papelera de reciclaje | ✅ |
| 8 | 📋 Logs antiguos (>7 días) | ✅ |
| 9 | 🔄 Caché Windows Update | ✅ |
| 10 | 📊 Informes de errores (WER) | ✅ |
| 11 | ⚡ Prefetch (>30 días) | ✅ |

**Opción 99:** Limpia todas las categorías seguras de una vez.

**Seguridad:**
- ⚠️ Las descargas **NUNCA** se eliminan automáticamente
- 📝 Genera log de todo lo eliminado en `C:\DiskCleanup\Logs\`
- 🔄 Los archivos eliminados van a la Papelera de Reciclaje

---

### 3. Maintenance.ps1 — Mantenimiento Diario Automático

Script optimizado para ejecución automática como tarea programada.

**Ejecución manual:**
```powershell
.\Maintenance.ps1
.\Maintenance.ps1 -AlertThresholdPercent 15  # Alertar si < 15% libre
```

**Funcionalidades:**
- 🧹 Limpia todas las categorías seguras automáticamente
- 📊 Genera reporte diario en `C:\DiskCleanup\Logs\`
- 🔄 Rotación automática de logs (mantiene 30 días)
- ⚠️ Alerta si el espacio libre es crítico (< 10%)
- 📝 Escribe evento en Windows Event Log si hay alerta

**NO elimina:**
- ❌ Descargas del usuario
- ❌ Documentos del usuario
- ❌ Archivos de aplicaciones
- ❌ Archivos del sistema críticos

---

### 4. Setup-ScheduledTask.bat — Configurador

Crea la tarea programada en Windows para ejecución automática.

**Ejecución:**
```
Clic derecho → Ejecutar como administrador
```

**Qué hace:**
1. Verifica permisos de administrador
2. Configura política de ejecución de PowerShell
3. Crea carpetas de trabajo en `C:\DiskCleanup\`
4. Crea tarea programada "DailyDiskMaintenance"
5. Opcionalmente ejecuta el mantenimiento inmediatamente

**Configuración de la tarea:**
- Nombre: `DailyDiskMaintenance`
- Frecuencia: Diaria
- Hora: 03:00 AM
- Ejecuta como: SYSTEM
- Privilegios: Highest

---

## 📂 Estructura de Datos Generados

```
C:\DiskCleanup\
├── Logs\
│   ├── maintenance-2026-03-24_03-00-00.txt    # Log detallado
│   ├── maintenance-summary-2026-03-24.txt     # Resumen diario
│   ├── cleanup-2026-03-24_10-30-00.txt        # Log de limpieza manual
│   └── ...                                    # Rotación automática (30 días)
├── Reports\
│   ├── disk-analysis-2026-03-24_10-00-00.html # Reporte interactivo
│   └── cleanable-categories-2026-03-24.csv    # Datos CSV
```

## 🔧 Comandos Útiles

### Verificar tarea programada
```cmd
schtasks /query /tn "DailyDiskMaintenance"
```

### Ejecutar mantenimiento manualmente
```cmd
schtasks /run /tn "DailyDiskMaintenance"
```

### Eliminar tarea programada
```cmd
schtasks /delete /tn "DailyDiskMaintenance" /f
```

### Ver logs recientes
```powershell
Get-Content "C:\DiskCleanup\Logs\maintenance-*.txt" -Tail 50
```

### Ejecutar análisis desde PowerShell
```powershell
Set-Location C:\DiskCleanupTool
.\Analyze-Disk.ps1
```

## ⚙️ Personalización

### Cambiar hora de ejecución
Edita `Setup-ScheduledTask.bat` y cambia la línea:
```batch
/st 03:00
```
Por tu hora preferida (formato 24h).

### Cambiar umbral de alerta
Edita `Maintenance.ps1` y cambia:
```powershell
[int]$AlertThresholdPercent = 10
```
Por tu porcentaje preferido (ej: 15 para alertar al 15%).

### Agregar categorías de limpieza
Edita el array `$CleanupCategories` en `Clean-Disk.ps1` o `$cleanupTasks` en `Maintenance.ps1`.

### Excluir carpetas de limpieza
Agrega las rutas que quieras proteger al inicio de los scripts.

## 🛡️ Medidas de Seguridad

1. **Nunca elimina archivos del usuario** sin confirmación explícita
2. **Modo interactivo** muestra espacio estimado antes de limpiar
3. **Logs completos** de todo lo eliminado
4. **Papelera de reciclaje** como respaldo (puedes restaurar)
5. **Excluye carpetas críticas**: System32, Program Files, Documents
6. **Archivos en uso** se omiten automáticamente

## ❓ Solución de Problemas

### "No se puede ejecutar scripts"
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Acceso denegado" al ejecutar
Ejecutar como Administrador (clic derecho → Ejecutar como administrador).

### La tarea programada no se ejecuta
```cmd
schtasks /query /tn "DailyDiskMaintenance" /v /fo list
```
Verificar estado y última ejecución.

### Los logs muestran errores de "archivo en uso"
Es normal. Algunos archivos están siendo usados por el sistema. Se omiten automáticamente.

### Quiero restaurar archivos eliminados
Revisa la **Papelera de Reciclaje** de Windows. Los archivos eliminados van ahí primero.

## 📝 Notas Técnicas

- **Requiere:** PowerShell 5.1+ (incluido en Windows 10/11)
- **Compatibilidad:** Windows 10, Windows 11
- **Privilegios:** Administrador para Setup y Windows Update cache
- **Logs:** Se mantienen 30 días por defecto
- **Rendimiento:** El análisis puede tardar 2-10 minutos dependiendo del tamaño del disco

## 📄 Licencia

Herramienta creada para uso personal. Sin restricciones de uso.

---

**Última actualización:** Marzo 2026