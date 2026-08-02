# 🎮 Hyprland Discord Widget

Un widget elegante, inteligente e interactivo de **Discord** diseñado para **Hyprland** y **Quickshell**. Transforma la ventana oficial de Discord en un widget desplegable flotante que aparece justo debajo de la barra superior al presionar un botón.

---

## ⚡ Instalación Rápida (1 Solo Comando)

Copia y pega este comando en tu terminal para instalar y configurar todo automáticamente:

```bash
curl -fsSL https://raw.githubusercontent.com/Davidzb16/Hyprland-Discord-Widget/main/install.sh | bash
```

---

## 💡 ¿Qué hace este Widget?

- 📍 **Desplegable Inteligente**: Transforma la ventana oficial de Discord (o Vesktop / Flatpak) en un panel de control emergente posicionado dinámicamente debajo de la barra superior.
- 🖥️ **Soporte Multi-Monitor & DPI**: Detecta automáticamente el monitor activo y su escala (1.0x, 1.5x, 4K) para asegurar que la ventana aparezca 100% visible sin recortes en los bordes.
- 🎨 **Animaciones Fluidas de la Shell**: Utiliza una transición suave de deslizamiento (*Slide Top*) al abrirse desde la barra superior y al cerrarse.
- 🔒 **Bloqueo Rígido de Posición**: Incluye un demonio ligero en segundo plano gestionado por `systemd` que previene el arrastre o movimiento accidental con el ratón.
- 🔀 **Prevención de Superposición de Widgets**: Si abres otro widget en la barra superior (*Volumen, Red, Batería, etc.*), Discord se oculta automáticamente para evitar empalmes en la pantalla.
- 📌 **Independiente de Tiling**: La ventana es totalmente flotante y fijada, garantizando que jamás altere las dimensiones ni el diseño del resto de tus aplicaciones abiertas.

---

## 🛠️ Requisitos
- **Hyprland** (v0.50+)
- **Python 3** y `jq`
- **Quickshell** (Opcional, para la integración del botón en el TopBar)
- Aplicación de Discord instalada (Flatpak o paquete nativo)

---

## 🚀 Uso Rápido
- **Abrir / Cerrar el widget**:
  ```bash
  python3 ~/.config/hypr/scripts/position_discord_widget.py
  ```
- **Integración con `qs_manager.sh` (Quickshell)**:
  ```bash
  ~/.config/hypr/scripts/qs_manager.sh toggle discord
  ```

---

## 📜 Licencia
Licencia MIT. ¡Siéntete libre de modificarlo y mejorar tu Rice de Hyprland! 🎨
