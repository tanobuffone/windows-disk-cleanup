# Disk Cleanup Tool v2.0 🧹

Herramienta avanzada para análisis, limpieza y mantenimiento automático del disco C: en Windows, con interfaz UX profesional y 3 niveles de experiencia.

## 📁 Estructura del Proyecto

```
C:\DiskCleanupTool\
├── DiskCleanup-Tool.ps1      # Script principal unificado
├── Modules\
│   ├── DiskAnalysis.psm1     # Funciones de análisis
│   ├── DiskCleanup.psm1      # Funciones de limpieza
│   ├── UI-Advanced.psm1      # Sistema de UI/UX
│   └── Config.psm1           # Gestión de configuración
├── Config\
│   └── settings.json         # Configuración persistente
├── Analyze-Disk.ps1          # (Legacy) Análisis básico
├── Clean-Disk.ps1            # (Legacy) Limpieza interactiva
├── Maintenance.ps1           # (Legacy) Mantenimiento automático
├── Setup-ScheduledTask.bat   # Configurador de tarea programada
└── README.md                 # Esta documentación
```

## 🎨 Niveles de UX (Focus Levels)

### 🟢 NIVEL BÁSICO — "Solo quiero liberar espacio"
Ideal para usuarios casuales. Opciones simples:
- **[L]** Limpieza rápida automática
- **[V]** Ver análisis detallado
- **[M]** Cambiar modo

### 🟡 NIVEL INTERMEDIO — "Quiero control"
Para usuarios que desean personalizar:
- Resumen visual con barras de progreso
- Indicador de seguridad por categoría
- Limpieza personalizada (selección múltiple)
- Análisis detallado + reporte HTML

### 🔴 NIVEL AVANZADO — "Control total"
Para usuarios técnicos:
- Tabla completa con todas las categorías
- Selección múltiple por número o rango
- Comandos abreviados ([A], [C], [E], [S], [D], [X])
- Escaneo personalizado de rutas
- Exportación de reportes

## 🚀 Instalación Rápida

1. **Copia la carpeta** a tu Windows (ej: `C:\DiskCleanupTool\`)

2. **Ejecuta el script principal:**
   ```powershell
   .\DiskCleanup-Tool.ps1
   ```

3. **Primera ejecución:** Te preguntará qué nivel prefieres (Básico/Intermedio/Avanzado)

4. **Configura tarea programada** (opcional):
   ```
   Clic derecho en Setup-ScheduledTask.bat → Ejecutar como administrador
   ```

## 📊 Uso del Script Principal

### Modo Interactivo (por defecto)
```powershell
.\DiskCleanup-Tool.ps1
```
Muestra el menú según tu nivel de experiencia guardado.

### Modo Auto (limpieza automática)
```powershell
.\DiskCleanup-Tool.ps1 -Auto
```
Ejecuta limpieza de categorías seguras sin interacción.

### Modo Silencioso (para scripting)
```powershell
.\DiskCleanup-Tool.ps1 -Auto -Silent
```
Limpieza automática sin salida visible (para tareas programadas).

### Modo específico
```powershell
.\DiskCleanup-Tool.ps1 -Mode 1   # Forzar modo Básico
.\DiskCleanup-Tool.ps1 -Mode 2   # Forzar modo Intermedio
.\DiskCleanup-Tool.ps1 -Mode 3   # Forzar modo Avanzado
```

## 🧹 Categorías Limpiables (14)

| # | Categoría | Seguro | Edad mín. |
|---|-----------|--------|-----------|
| 1 | Temporales usuario | ✅ | 7 días |
| 2 | Temporales Windows | ✅ | 7 días |
| 3 | Prefetch | ✅ | 30 días |
| 4 | Caché Windows Update | ✅ | Any |
| 5 | Papelera reciclaje | ✅ | Any |
| 6 | Logs Windows | ✅ | 7 días |
| 7 | Reportes WER | ✅ | 7 días |
| 8 | Descargas | ⚠️ | 30 días |
| 9 | Chrome Cache | ✅ | Any |
| 10 | Chrome Code Cache | ✅ | Any |
| 11 | Chrome GPU Cache | ✅ | Any |
| 12 | Firefox Cache | ✅ | Any |
| 13 | Edge Cache | ✅ | Any |
| 14 | Edge Code Cache | ✅ | Any |

## ⌨️ Atajos de Teclado

| Tecla | Acción |
|-------|--------|
| [H] | Ayuda |
| [M] | Cambiar modo |
| [Q] | Salir |
| [R] | Refrescar |
| [0] | Volver/Salir |

## ⚙️ Configuración

El archivo `Config\settings.json` guarda tus preferencias:

```json
{
  "UserMode": 2,
  "LogPath": "C:\\DiskCleanup\\Logs",
  "ReportPath": "C:\\DiskCleanup\\Reports",
  "AlertThresholdPercent": 10,
  "AutoConfirmSafe": false,
  "LastRun": "2026-03-24 22:00:00",
  "TotalCleanedGB": 15.5
}
```

## 📂 Estructura de Datos Generados

```
C:\DiskCleanup\
├── Config\
│   └── settings.json              # Preferencias del usuario
├── Logs\
│   ├── cleanup-2026-03-24_10-30-00.txt
│   └── ...                        # Rotación automática (30 días)
└── Reports\
    └── disk-analysis-*.html       # Reportes generados
```

## 🔧 Comandos Útiles

### Ejecutar limpieza automática
```powershell
.\DiskCleanup-Tool.ps1 -Auto
```

### Ejecutar como tarea programada
```cmd
powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\DiskCleanupTool\DiskCleanup-Tool.ps1" -Auto -Silent
```

### Ver configuración actual
```powershell
Import-Module .\Modules\Config.psm1
Load-Config | ConvertTo-Json
```

### Resetear configuración
```powershell
Remove-Item "C:\DiskCleanup\Config\settings.json" -Force
```

## 🛡️ Medidas de Seguridad

1. **Confirmación explícita** para categorías no seguras
2. **Logs completos** de todas las operaciones
3. **Archivos a Papelera** (restaurables)
4. **Exclusión de carpetas críticas** del sistema
5. **Rotación de logs** (30 días)

## ❓ Solución de Problemas

### "No se puede ejecutar scripts"
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "Error cargando módulos"
Verifica que la carpeta `Modules\` exista y contenga los 4 archivos `.psm1`.

### La configuración no se guarda
Verifica permisos de escritura en `C:\DiskCleanup\Config\`.

### Los logs muestran "archivo en uso"
Es normal. Algunos archivos están siendo usados por el sistema. Se omiten automáticamente.

## 📝 Notas Técnicas

- **Requiere:** PowerShell 5.1+ (incluido en Windows 10/11)
- **Compatibilidad:** Windows 10, Windows 11
- **Privilegios:** Administrador para Windows Update cache
- **Logs:** Rotación automática cada 30 días
- **Configuración:** Persiste entre sesiones en `settings.json`

## 📄 Licencia

Herramienta creada para uso personal. Sin restricciones de uso.

---

**Versión:** 2.0  
**Última actualización:** Marzo 2026  
**Repositorio:** https://github.com/tanobuffone/windows-disk-cleanup