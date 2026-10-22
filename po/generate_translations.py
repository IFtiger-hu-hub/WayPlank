#!/usr/bin/env python3
#
#  Copyright (C) 2011-2012 Robert Dyer, Michal Hruby, Rico Tzschichholz
#  Copyright (C) 2026 Sergio Melas
#  Copyright (C) 2026 史有虎 (IFtiger-hu)
#
#  This file is part of WayPlank.
#
#  WayPlank is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  WayPlank is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

import os, json, re, subprocess

translations = {
    "(Maximum)": {
        "zh_CN": "(最大)",
        "it": "(Massimo)",
        "es": "(Máximo)",
        "fr": "(Maximum)",
        "ca": "(Màxim)"
    },
    "(Minimum)": {
        "zh_CN": "(最小)",
        "it": "(Minimo)",
        "es": "(Mínimo)",
        "fr": "(Minimum)",
        "ca": "(Mínim)"
    },
    "3-Day Forecast": {
        "zh_CN": "未来3天天气预报",
        "it": "Previsioni a 3 giorni",
        "es": "Pronóstico a 3 días",
        "fr": "Prévisions sur 3 jours",
        "ca": "Previsió a 3 dies"
    },
    "A theme named '%s' already exists.\\nDo you want to replace it?": {
        "zh_CN": "已存在名为 '%s' 的主题。\\n是否替换？",
        "it": "Un tema chiamato '%s' esiste già.\\nVuoi sostituirlo?",
        "es": "Ya existe un tema llamado '%s'.\\n¿Desea reemplazarlo?",
        "fr": "Un thème nommé '%s' existe déjà.\\nVoulez-vous le remplacer ?",
        "ca": "Ja existeix un tema anomenat '%s'.\\nVoleu substituir-lo?"
    },
    "A_pplications...": {
        "zh_CN": "窗口与应用(_P)...",
        "it": "A_pplicazioni...",
        "es": "A_plicaciones...",
        "fr": "A_pplications...",
        "ca": "A_plicacions..."
    },
    "About WayPlank": {
        "zh_CN": "关于 WayPlank",
        "it": "Informazioni su WayPlank",
        "es": "Acerca de WayPlank",
        "fr": "À propos de WayPlank",
        "ca": "Quant a WayPlank"
    },
    "Accordion Auto-Retention": {
        "zh_CN": "折叠抽屉自动保持",
        "it": "Auto-ritenzione a fisarmonica",
        "es": "Auto-retención en acordeón",
        "fr": "Rétention automatique en accordéon",
        "ca": "Autoretenció en acordió"
    },
    "Adjust display brightness with multi-monitor hardware sync": {
        "zh_CN": "调节屏幕亮度并支持多显示器硬件同步",
        "it": "Regola la luminosità dello schermo con sincronizzazione hardware multimonitor",
        "es": "Ajusta el brillo de pantalla con sincronización hardware multimonitor",
        "fr": "Ajuste la luminosité avec synchronisation matérielle multi-écrans",
        "ca": "Ajusta la brillantor de la pantalla amb sincronització multimonitor"
    },
    "Adjust master audio volume up or down": {
        "zh_CN": "调节系统主音量大小",
        "it": "Regola il volume audio principale",
        "es": "Ajusta el volumen de audio principal",
        "fr": "Règle le volume audio principal",
        "ca": "Ajusta el volum d'àudio principal"
    },
    "Align by Type (Preferences)": {
        "zh_CN": "按类型对齐 (首选项)",
        "it": "Allinea per tipo (Preferenze)",
        "es": "Alinear por tipo (Preferencias)",
        "fr": "Aligner par type (Préférences)",
        "ca": "Alinea per tipus (Preferències)"
    },
    "All Files": {
        "zh_CN": "所有文件",
        "it": "Tutti i file",
        "es": "Todos los archivos",
        "fr": "Tous les fichiers",
        "ca": "Tots els fitxers"
    },
    "Application": {
        "zh_CN": "应用程序",
        "it": "Applicazione",
        "es": "Aplicación",
        "fr": "Application",
        "ca": "Aplicació"
    },
    "Application is running (%d windows)": {
        "zh_CN": "应用程序正在运行 (%d 个窗口)",
        "it": "L'applicazione è in esecuzione (%d finestre)",
        "es": "La aplicación está en ejecución (%d ventanas)",
        "fr": "L'application est en cours d'exécution (%d fenêtres)",
        "ca": "L'aplicació s'està executant (%d finestres)"
    },
    "Apply": {
        "zh_CN": "应用",
        "it": "Applica",
        "es": "Aplicar",
        "fr": "Appliquer",
        "ca": "Aplica"
    },
    "Are you sure you want to delete the theme '%s'?\\nThis will remove it from ~/.local/share/wayplank/themes/.": {
        "zh_CN": "确定要删除主题 '%s' 吗？\\n此操作将从 ~/.local/share/wayplank/themes/ 中移除该主题。",
        "it": "Sei sicuro di voler eliminare il tema '%s'?\\nVerrà rimosso da ~/.local/share/wayplank/themes/.",
        "es": "¿Seguro que desea eliminar el tema '%s'?\\nSe eliminará de ~/.local/share/wayplank/themes/.",
        "fr": "Voulez-vous vraiment supprimer le thème '%s' ?\\nIl sera supprimé de ~/.local/share/wayplank/themes/.",
        "ca": "Segur que voleu suprimir el tema '%s'?\\nS'eliminarà de ~/.local/share/wayplank/themes/."
    },
    "Are you sure you want to log out of this session?": {
        "zh_CN": "确定要退出此会话吗？",
        "it": "Sei sicuro di voler terminare questa sessione?",
        "es": "¿Seguro que desea cerrar esta sesión?",
        "fr": "Voulez-vous vraiment fermer cette session ?",
        "ca": "Segur que voleu tancar aquesta sessió?"
    },
    "Are you sure you want to log out of your current session?": {
        "zh_CN": "确定要注销当前会话吗？",
        "it": "Sei sicuro di voler terminare la sessione corrente?",
        "es": "¿Seguro que desea cerrar su sesión actual?",
        "fr": "Voulez-vous vraiment fermer votre session actuelle ?",
        "ca": "Segur que voleu tancar la sessió actual?"
    },
    "Are you sure you want to restart your computer?": {
        "zh_CN": "确定要重启计算机吗？",
        "it": "Sei sicuro di voler riavviare il computer?",
        "es": "¿Seguro que desea reiniciar el ordenador?",
        "fr": "Voulez-vous vraiment redémarrer votre ordinateur ?",
        "ca": "Segur que voleu reiniciar l'ordinador?"
    },
    "Are you sure you want to restart your computer? Unsaved changes will be lost.": {
        "zh_CN": "确定要重启计算机吗？未保存的更改将会丢失。",
        "it": "Sei sicuro di voler riavviare il computer? Le modifiche non salvate andranno perse.",
        "es": "¿Seguro que desea reiniciar el ordenador? Se perderán los cambios no guardados.",
        "fr": "Voulez-vous vraiment redémarrer votre ordinateur ? Les modifications non enregistrées seront perdues.",
        "ca": "Segur que voleu reiniciar l'ordinador? Es perdran els canvis no desats."
    },
    "Are you sure you want to shut down your computer?": {
        "zh_CN": "确定要关闭计算机吗？",
        "it": "Sei sicuro di voler spegnere il computer?",
        "es": "¿Seguro que desea apagar el ordenador?",
        "fr": "Voulez-vous vraiment éteindre votre ordinateur ?",
        "ca": "Segur que voleu apagar l'ordinador?"
    },
    "Are you sure you want to turn off your computer? Unsaved changes will be lost.": {
        "zh_CN": "确定要关闭计算机吗？未保存的更改将会丢失。",
        "it": "Sei sicuro di voler spegnere il computer? Le modifiche non salvate andranno perse.",
        "es": "¿Seguro que desea apagar el ordenador? Se perderán los cambios no guardados.",
        "fr": "Voulez-vous vraiment éteindre votre ordinateur ? Les modifications non enregistrées seront perdues.",
        "ca": "Segur que voleu apagar l'ordinador? Es perdran els canvis no desats."
    },
    "Back": {
        "zh_CN": "返回",
        "it": "Indietro",
        "es": "Atrás",
        "fr": "Retour",
        "ca": "Enrere"
    },
    "Battery": {
        "zh_CN": "电池",
        "it": "Batteria",
        "es": "Batería",
        "fr": "Batterie",
        "ca": "Bateria"
    },
    "Battery: %d%% (%s)": {
        "zh_CN": "电池: %d%% (%s)",
        "it": "Batteria: %d%% (%s)",
        "es": "Batería: %d%% (%s)",
        "fr": "Batterie : %d%% (%s)",
        "ca": "Bateria: %d%% (%s)"
    },
    "Battery: %d%% (Charging)": {
        "zh_CN": "电池: %d%% (充电中)",
        "it": "Batteria: %d%% (In carica)",
        "es": "Batería: %d%% (Cargando)",
        "fr": "Batterie : %d%% (En charge)",
        "ca": "Bateria: %d%% (Carregant)"
    },
    "Battery: %d%% (Full)": {
        "zh_CN": "电池: %d%% (充满)",
        "it": "Batteria: %d%% (Carica)",
        "es": "Batería: %d%% (Llena)",
        "fr": "Batterie : %d%% (Pleine)",
        "ca": "Bateria: %d%% (Plena)"
    },
    "Brightness: %d%%": {
        "zh_CN": "屏幕亮度: %d%%",
        "it": "Luminosità: %d%%",
        "es": "Brillo: %d%%",
        "fr": "Luminosité : %d%%",
        "ca": "Brillantor: %d%%"
    },
    "Calendar": {
        "zh_CN": "日历",
        "it": "Calendario",
        "es": "Calendario",
        "fr": "Calendrier",
        "ca": "Calendari"
    },
    "Cancel": {
        "zh_CN": "取消",
        "it": "Annulla",
        "es": "Cancelar",
        "fr": "Annuler",
        "ca": "Cancel·la"
    },
    "Capture Active Window": {
        "zh_CN": "截取活动窗口",
        "it": "Cattura finestra attiva",
        "es": "Capturar ventana activa",
        "fr": "Capturer la fenêtre active",
        "ca": "Captura la finestra activa"
    },
    "Capture Area / Rectangular...": {
        "zh_CN": "截取选定区域...",
        "it": "Cattura area / rettangolare...",
        "es": "Capturar área / rectangular...",
        "fr": "Capturer une zone / rectangulaire...",
        "ca": "Captura una àrea / rectangular..."
    },
    "Capture Entire Screen": {
        "zh_CN": "截取全屏",
        "it": "Cattura l'intero schermo",
        "es": "Capturar toda la pantalla",
        "fr": "Capturer tout l'écran",
        "ca": "Captura tota la pantalla"
    },
    "Change Icon - %s": {
        "zh_CN": "更改图标 - %s",
        "it": "Cambia icona - %s",
        "es": "Cambiar icono - %s",
        "fr": "Changer l'icône - %s",
        "ca": "Canvia la icona - %s"
    },
    "Change _Icon...": {
        "zh_CN": "更改图标(_I)...",
        "it": "Cambia _icona...",
        "es": "Cambiar _icono...",
        "fr": "Changer d'_icône...",
        "ca": "Canvia la _icona..."
    },
    "Checking weather...": {
        "zh_CN": "正在获取天气...",
        "it": "Verifica meteo in corso...",
        "es": "Consultando el tiempo...",
        "fr": "Vérification de la météo...",
        "ca": "S'està comprovant el temps..."
    },
    "Choose a custom image file (PNG, SVG, ICO) from disk": {
        "zh_CN": "从磁盘选择自定义图像文件 (PNG, SVG, ICO)",
        "it": "Scegli un'immagine personalizzata (PNG, SVG, ICO) dal disco",
        "es": "Elija una imagen personalizada (PNG, SVG, ICO) del disco",
        "fr": "Choisir une image personnalisée (PNG, SVG, ICO) sur le disque",
        "ca": "Trieu una imatge personalitzada (PNG, SVG, ICO) del disc"
    },
    "Choose system icon or custom image for any launcher or folder drawer": {
        "zh_CN": "为启动器或文件夹抽屉选择系统图标或自定义图像",
        "it": "Scegli un'icona di sistema o un'immagine per lanciatori o cartelle",
        "es": "Elija icono del sistema o imagen personalizada para lanzadores o carpetas",
        "fr": "Choisir une icône système ou image pour les lanceurs ou dossiers",
        "ca": "Trieu una icona de sistema o imatge per a llançadors o carpetes"
    },
    "City / Location:": {
        "zh_CN": "城市 / 位置:",
        "it": "Città / Posizione:",
        "es": "Ciudad / Ubicación:",
        "fr": "Ville / Lieu :",
        "ca": "Ciutat / Ubicació:"
    },
    "Clear location (re-detect via IP)": {
        "zh_CN": "清除位置 (重新通过 IP 检测)",
        "it": "Azzera posizione (rileva da IP)",
        "es": "Borrar ubicación (detectar por IP)",
        "fr": "Effacer l'emplacement (redétecter par IP)",
        "ca": "Neteja la ubicació (redetecta per IP)"
    },
    "Clear sky": {
        "zh_CN": "晴朗",
        "it": "Sereno",
        "es": "Cielo despejado",
        "fr": "Ciel dégagé",
        "ca": "Cel serè"
    },
    "Click to expand": {
        "zh_CN": "点击展开",
        "it": "Fai clic per espandere",
        "es": "Haga clic para expandir",
        "fr": "Cliquer pour agrandir",
        "ca": "Feu clic per expandir"
    },
    "Clock": {
        "zh_CN": "时钟",
        "it": "Orologio",
        "es": "Reloj",
        "fr": "Horloge",
        "ca": "Rellotge"
    },
    "Close": {
        "zh_CN": "关闭",
        "it": "Chiudi",
        "es": "Cerrar",
        "fr": "Fermer",
        "ca": "Tanca"
    },
    "Close _All": {
        "zh_CN": "全部关闭(_A)",
        "it": "Chiudi _tutti",
        "es": "Cerrar _todos",
        "fr": "Tout _fermer",
        "ca": "Tanca-ho _tot"
    },
    "Confirm Session Action": {
        "zh_CN": "确认会话操作",
        "it": "Conferma azione sessione",
        "es": "Confirmar acción de sesión",
        "fr": "Confirmer l'action de session",
        "ca": "Confirma l'acció de la sessió"
    },
    "Connected": {
        "zh_CN": "已连接",
        "it": "Connesso",
        "es": "Conectado",
        "fr": "Connecté",
        "ca": "Connectat"
    },
    "Copy _IP Address": {
        "zh_CN": "复制 IP 地址(_I)",
        "it": "Copia indirizzo _IP",
        "es": "Copiar dirección _IP",
        "fr": "Copier l'adresse _IP",
        "ca": "Copia l'adreça _IP"
    },
    "Ctrl + Alt + Shift + Right Click": {
        "zh_CN": "Ctrl + Alt + Shift + 右键单击",
        "it": "Ctrl + Alt + Maiusc + Clic destro",
        "es": "Ctrl + Alt + Mayús + Clic derecho",
        "fr": "Ctrl + Alt + Maj + Clic droit",
        "ca": "Ctrl + Alt + Maj + Clic dret"
    },
    "Ctrl + Mouse Scroll Down": {
        "zh_CN": "Ctrl + 滚轮向下",
        "it": "Ctrl + Rotellina giù",
        "es": "Ctrl + Rueda del ratón abajo",
        "fr": "Ctrl + Molette bas",
        "ca": "Ctrl + Roda avall"
    },
    "Ctrl + Mouse Scroll Up": {
        "zh_CN": "Ctrl + 滚轮向上",
        "it": "Ctrl + Rotellina su",
        "es": "Ctrl + Rueda del ratón arriba",
        "fr": "Ctrl + Molette haut",
        "ca": "Ctrl + Roda amunt"
    },
    "Ctrl + Right Click": {
        "zh_CN": "Ctrl + 右键单击",
        "it": "Ctrl + Clic destro",
        "es": "Ctrl + Clic derecho",
        "fr": "Ctrl + Clic droit",
        "ca": "Ctrl + Clic dret"
    },
    "Cycle between all open windows of this application": {
        "zh_CN": "在当前应用程序的所有打开窗口之间循环切换",
        "it": "Scorri tra tutte le finestre aperte di questa applicazione",
        "es": "Alternar entre todas las ventanas abiertas de esta aplicación",
        "fr": "Parcourir toutes les fenêtres ouvertes de cette application",
        "ca": "Alterna entre totes les finestres obertes d'aquesta aplicació"
    },
    "Decrease dock icon size dynamically in real-time": {
        "zh_CN": "实时动态缩小 Dock 图标大小",
        "it": "Riduci dinamicamente la dimensione delle icone in tempo reale",
        "es": "Reduce el tamaño de los iconos dinámicamente en tiempo real",
        "fr": "Réduit dynamiquement la taille des icônes en temps réel",
        "ca": "Redueix dinàmicament la mida de les icones en temps real"
    },
    "Delete user theme '%s'": {
        "zh_CN": "删除用户主题 '%s'",
        "it": "Elimina tema utente '%s'",
        "es": "Eliminar tema de usuario '%s'",
        "fr": "Supprimer le thème utilisateur '%s'",
        "ca": "Suprimeix el tema d'usuari '%s'"
    },
    "Detecting location...": {
        "zh_CN": "正在定位...",
        "it": "Rilevamento posizione...",
        "es": "Detectando ubicación...",
        "fr": "Détection de l'emplacement...",
        "ca": "S'està detectant la ubicació..."
    },
    "Developer _Tools": {
        "zh_CN": "开发者工具(_T)",
        "it": "Strumenti di _sviluppo",
        "es": "Herramientas de _desarrollo",
        "fr": "Outils de _développement",
        "ca": "Eines de _desenvolupament"
    },
    "Device '%s' has been safely unmounted.": {
        "zh_CN": "设备 '%s' 已成功安全卸载。",
        "it": "Il dispositivo '%s' è stato smontato in sicurezza.",
        "es": "El dispositivo '%s' se ha desmontado de forma segura.",
        "fr": "Le périphérique '%s' a été démonté en toute sécurité.",
        "ca": "El dispositiu '%s' s'ha desmuntat de manera segura."
    },
    "Digital Clock": {
        "zh_CN": "数字时钟",
        "it": "Orologio digitale",
        "es": "Reloj digital",
        "fr": "Horloge numérique",
        "ca": "Rellotge digital"
    },
    "Display floating Cairo preview cards with live window thumbnails": {
        "zh_CN": "展开悬浮 Cairo 多窗口平铺卡片与实时缩略图",
        "it": "Mostra schede di anteprima Cairo fluttuanti con miniature dal vivo",
        "es": "Muestra tarjetas flotantes de previsualización Cairo con miniaturas en vivo",
        "fr": "Affiche les cartes de prévisualisation Cairo avec miniatures en direct",
        "ca": "Mostra targetes de previsualització Cairo flotants amb miniatures en viu"
    },
    "Docklet": {
        "zh_CN": "Docklet 插件",
        "it": "Docklet",
        "es": "Docklet",
        "fr": "Docklet",
        "ca": "Docklet"
    },
    "Docklets": {
        "zh_CN": "插件 / Docklets",
        "it": "Docklet",
        "es": "Docklets",
        "fr": "Docklets",
        "ca": "Docklets"
    },
    "Drag & Drop": {
        "zh_CN": "拖拽交互 (Drag & Drop)",
        "it": "Trascina e rilascia",
        "es": "Arrastrar y soltar",
        "fr": "Glisser-déposer",
        "ca": "Arrossega i deixa anar"
    },
    "Drag icon along dock (Categorized)": {
        "zh_CN": "沿停靠栏拖动图标 (分类排序模式)",
        "it": "Trascina icona lungo il dock (Categorizzato)",
        "es": "Arrastra icono por el dock (Categorizado)",
        "fr": "Glisser l'icône le long du dock (Catégorisé)",
        "ca": "Arrossega la icona pel dock (Categoritzat)"
    },
    "Drag icon along dock (Free Mode)": {
        "zh_CN": "沿停靠栏拖动图标 (自由排序模式)",
        "it": "Trascina icona lungo il dock (Modalità libera)",
        "es": "Arrastra icono por el dock (Modo libre)",
        "fr": "Glisser l'icône le long du dock (Mode libre)",
        "ca": "Arrossega la icona pel dock (Mode lliure)"
    },
    "Drag icon off dock": {
        "zh_CN": "将图标拖出停靠栏",
        "it": "Trascina icona fuori dal dock",
        "es": "Arrastra icono fuera del dock",
        "fr": "Glisser l'icône hors du dock",
        "ca": "Arrossega la icona fora del dock"
    },
    "Drawer stays open during menus & dialogs; full countdown (0.5s–20s) restarts on close": {
        "zh_CN": "菜单与弹窗激活期间抽屉保持常开；弹窗关闭后完整倒计时 (0.5s–20s) 自动重启",
        "it": "Il cassetto resta aperto durante menu e finestre; il conto alla rovescia (0.5s–20s) riparte alla chiusura",
        "es": "El cajón permanece abierto durante menús y diálogos; la cuenta regresiva (0.5s–20s) se reinicia al cerrar",
        "fr": "Le tiroir reste ouvert pendant les menus et boîtes de dialogue ; le compte à rebours (0,5s–20s) reprend à la fermeture",
        "ca": "El calaix es manté obert durant menús i diàlegs; el compte enrere complet (0,5s–20s) es reinicia en tancar"
    },
    "Drizzle": {
        "zh_CN": "毛毛雨",
        "it": "Pioggerella",
        "es": "Llovizna",
        "fr": "Bruine",
        "ca": "Plugim"
    },
    "Drop .desktop or folder": {
        "zh_CN": "拖放 .desktop 启动器或文件夹",
        "it": "Rilascia file .desktop o cartella",
        "es": "Soltar .desktop o carpeta",
        "fr": "Déposer un .desktop ou dossier",
        "ca": "Deixa anar .desktop o carpeta"
    },
    "Drop applications or files here": {
        "zh_CN": "拖放应用或文件至此",
        "it": "Rilascia qui applicazioni o file",
        "es": "Suelte aplicaciones o archivos aquí",
        "fr": "Déposer des applications ou des fichiers ici",
        "ca": "Deixeu anar aplicacions o fitxers aquí"
    },
    "Drop file on app icon": {
        "zh_CN": "拖放文件至应用图标",
        "it": "Rilascia file sull'icona dell'app",
        "es": "Soltar archivo en el icono de la app",
        "fr": "Déposer un fichier sur l'icône",
        "ca": "Deixa anar fitxer sobre la icona"
    },
    "Drop http:// or https:// URL onto browser icon to open in new tab": {
        "zh_CN": "将 http:// 或 https:// 网址拖放至浏览器图标直接在新标签页中打开",
        "it": "Rilascia un URL http:// o https:// sull'icona del browser per aprirlo in una nuova scheda",
        "es": "Suelta una URL http:// o https:// sobre el navegador para abrir en nueva pestaña",
        "fr": "Déposer une URL http:// ou https:// sur le navigateur pour l'ouvrir dans un nouvel onglet",
        "ca": "Deixa anar un URL http:// o https:// a la icona del navegador per obrir-lo en una pestanya nova"
    },
    "Drop to add to dock": {
        "zh_CN": "松手固定至 Dock",
        "it": "Rilascia per aggiungere al dock",
        "es": "Soltar para añadir al dock",
        "fr": "Déposer pour ajouter au dock",
        "ca": "Deixa anar per afegir al dock"
    },
    "Drop to copy into %s": {
        "zh_CN": "松手复制到 %s",
        "it": "Rilascia per copiare in %s",
        "es": "Soltar para copiar en %s",
        "fr": "Déposer pour copier dans %s",
        "ca": "Deixa anar per copiar a %s"
    },
    "Drop to open with %s": {
        "zh_CN": "松手使用 %s 打开",
        "it": "Rilascia per aprire con %s",
        "es": "Soltar para abrir con %s",
        "fr": "Déposer pour ouvrir avec %s",
        "ca": "Deixa anar per obrir amb %s"
    },
    "Drop web URL on browser": {
        "zh_CN": "拖放网页 URL 至浏览器",
        "it": "Rilascia URL web sul browser",
        "es": "Soltar URL web en el navegador",
        "fr": "Déposer une URL sur le navigateur",
        "ca": "Deixa anar URL web al navegador"
    },
    "Dynamic Counterpart Swapping": {
        "zh_CN": "动态明暗对偶主题切换",
        "it": "Scambio dinamico tema chiaro/scuro",
        "es": "Cambio dinámico claro/oscuro",
        "fr": "Basculement dynamique clair/sombre",
        "ca": "Canvi dinàmic clar/fosc"
    },
    "Dynamic zoom, overflow scrolling, theme management and developer tools": {
        "zh_CN": "动态悬浮缩放、超限平滑翻页、实时主题管理器与开发者调试工具",
        "it": "Zoom dinamico, scorrimento per overflow, gestione temi e strumenti di sviluppo",
        "es": "Zoom dinámico, desplazamiento por desbordamiento, gestión de temas y herramientas de desarrollo",
        "fr": "Zoom dynamique, défilement par débordement, gestion des thèmes et outils de développement",
        "ca": "Zoom dinàmic, desplaçament per desbordament, gestió de temes i eines de desenvolupador"
    },
    "Eject '%s'": {
        "zh_CN": "弹出 '%s'",
        "it": "Espelli '%s'",
        "es": "Expulsar '%s'",
        "fr": "Éjecter '%s'",
        "ca": "Expulsa '%s'"
    },
    "Eject All Devices": {
        "zh_CN": "弹出所有设备",
        "it": "Espelli tutti i dispositivi",
        "es": "Expulsar todos los dispositivos",
        "fr": "Éjecter tous les périphériques",
        "ca": "Expulsa tots els dispositius"
    },
    "Empty": {
        "zh_CN": "空",
        "it": "Vuoto",
        "es": "Vacío",
        "fr": "Vide",
        "ca": "Buit"
    },
    "Empty Folder": {
        "zh_CN": "空文件夹",
        "it": "Cartella vuota",
        "es": "Carpeta vacía",
        "fr": "Dossier vide",
        "ca": "Carpeta buida"
    },
    "Ethernet: %s": {
        "zh_CN": "有线网络: %s",
        "it": "Ethernet: %s",
        "es": "Ethernet: %s",
        "fr": "Ethernet : %s",
        "ca": "Ethernet: %s"
    },
    "Ethernet: %s - %s": {
        "zh_CN": "有线网络: %s - %s",
        "it": "Ethernet: %s - %s",
        "es": "Ethernet: %s - %s",
        "fr": "Ethernet : %s - %s",
        "ca": "Ethernet: %s - %s"
    },
    "Feels like %d%s": {
        "zh_CN": "体感温度 %d%s",
        "it": "Percepita %d%s",
        "es": "Sensación térmica %d%s",
        "fr": "Ressenti %d%s",
        "ca": "Sensació de %d%s"
    },
    "Fits on screen without shrinking (limit: %dpx)": {
        "zh_CN": "在不缩小的情况下完全适应屏幕 (容纳上限: %dpx)",
        "it": "Entra nello schermo senza rimpicciolirsi (limite: %dpx)",
        "es": "Cabe en pantalla sin encogerse (límite: %dpx)",
        "fr": "Tient sur l'écran sans rétrécissement (limite : %dpx)",
        "ca": "Cap a la pantalla sense reducció (límit: %dpx)"
    },
    "Focus the next open window of this application": {
        "zh_CN": "顺次聚焦该应用的下一个打开窗口",
        "it": "Focalizza la finestra successiva di questa applicazione",
        "es": "Enfoca la siguiente ventana abierta de esta aplicación",
        "fr": "Active la fenêtre suivante de cette application",
        "ca": "Enfoca la finestra següent d'aquesta aplicació"
    },
    "Foggy": {
        "zh_CN": "有雾",
        "it": "Nebbia",
        "es": "Niebla",
        "fr": "Brouillard",
        "ca": "Boira"
    },
    "Folder": {
        "zh_CN": "文件夹",
        "it": "Cartella",
        "es": "Carpeta",
        "fr": "Dossier",
        "ca": "Carpeta"
    },
    "Force launch a NEW instance of the application": {
        "zh_CN": "强制启动该应用程序的新实例",
        "it": "Forza l'avvio di una NUOVA istanza dell'applicazione",
        "es": "Forzar inicio de una NUEVA instancia",
        "fr": "Forcer le lancement d'une NOUVELLE instance",
        "ca": "Força l'inici d'una NOVA instància"
    },
    "Freely reorder launchers, docklets, and folders anywhere on the dock": {
        "zh_CN": "在停靠栏任意位置自由拖拽重排启动器、插件和文件夹",
        "it": "Riordina liberamente lanciatori, docklet e cartelle ovunque nel dock",
        "es": "Reordena libremente lanzadores, docklets y carpetas en el dock",
        "fr": "Réorganisez librement lanceurs, docklets et dossiers sur le dock",
        "ca": "Reordena lliurement llançadors, docklets i carpetes a qualsevol lloc del dock"
    },
    "Freezing drizzle": {
        "zh_CN": "冻毛毛雨",
        "it": "Pioviggine gelata",
        "es": "Llovizna helada",
        "fr": "Bruine verglaçante",
        "ca": "Plugim gebrador"
    },
    "Freezing rain": {
        "zh_CN": "冻雨",
        "it": "Pioggia gelata",
        "es": "Lluvia helada",
        "fr": "Pluie verglaçante",
        "ca": "Pluja gebradora"
    },
    "Fully supported compositors: %s": {
        "zh_CN": "完全支持的混成器: %s",
        "it": "Compositori pienamente supportati: %s",
        "es": "Compositores totalmente compatibles: %s",
        "fr": "Compositeurs entièrement pris en charge : %s",
        "ca": "Compositors plenament compatibles: %s"
    },
    "Fully supported compositors: none": {
        "zh_CN": "完全支持的混成器: 无",
        "it": "Compositori pienamente supportati: nessuno",
        "es": "Compositores totalmente compatibles: ninguno",
        "fr": "Compositeurs entièrement pris en charge : aucun",
        "ca": "Compositors plenament compatibles: cap"
    },
    "Gateway: %s": {
        "zh_CN": "网关: %s",
        "it": "Gateway: %s",
        "es": "Puerta de enlace: %s",
        "fr": "Passerelle : %s",
        "ca": "Passarel·la: %s"
    },
    "Heavy rain": {
        "zh_CN": "大雨",
        "it": "Pioggia forte",
        "es": "Lluvia fuerte",
        "fr": "Forte pluie",
        "ca": "Pluja forta"
    },
    "Heavy snow": {
        "zh_CN": "大雪",
        "it": "Neve forte",
        "es": "Nieve fuerte",
        "fr": "Forte neige",
        "ca": "Neu forta"
    },
    "Help": {
        "zh_CN": "帮助",
        "it": "Aiuto",
        "es": "Ayuda",
        "fr": "Aide",
        "ca": "Ajuda"
    },
    "Hide Dock": {
        "zh_CN": "停靠栏隐藏与避让",
        "it": "Nascondi dock",
        "es": "Ocultar dock",
        "fr": "Masquer le dock",
        "ca": "Amaga el dock"
    },
    "Hover or click to toggle docklet drawer; directional indicators (▸ / ◂ / ▾ / ▴) show state": {
        "zh_CN": "悬停或点击展开/折叠插件抽屉；方向指示箭头 (▸ / ◂ / ▾ / ▴) 实时展示抽屉状态",
        "it": "Passa sopra o fai clic per aprire il cassetto docklet; gli indicatori (▸ / ◂ / ▾ / ▴) mostrano lo stato",
        "es": "Pasa o haz clic para alternar el cajón de docklets; los indicadores (▸ / ◂ / ▾ / ▴) muestran el estado",
        "fr": "Survoler ou cliquer pour basculer le tiroir de docklets ; les flèches (▸ / ◂ / ▾ / ▴) indiquent l'état",
        "ca": "Passa el cursor o fes clic per alternar el calaix del docklet; els indicadors direccionals (▸ / ◂ / ▾ / ▴) mostren l'estat"
    },
    "Hover over icon during DND": {
        "zh_CN": "拖拽过程中在图标上悬停",
        "it": "Passa sopra l'icona durante il trascinamento (DND)",
        "es": "Pasa sobre el icono durante el arrastre (DND)",
        "fr": "Survoler l'icône pendant le glisser-déposer",
        "ca": "Passa el cursor sobre la icona durant l'arrossegament"
    },
    "IP: %s": {
        "zh_CN": "IP 地址: %s",
        "it": "IP: %s",
        "es": "IP: %s",
        "fr": "IP : %s",
        "ca": "IP: %s"
    },
    "Image Files (*.png, *.svg, *.ico, *.jpg)": {
        "zh_CN": "图像文件 (*.png, *.svg, *.ico, *.jpg)",
        "it": "File immagine (*.png, *.svg, *.ico, *.jpg)",
        "es": "Archivos de imagen (*.png, *.svg, *.ico, *.jpg)",
        "fr": "Fichiers image (*.png, *.svg, *.ico, *.jpg)",
        "ca": "Fitxers d'imatge (*.png, *.svg, *.ico, *.jpg)"
    },
    "Increase dock icon size dynamically in real-time": {
        "zh_CN": "实时动态放大 Dock 图标大小",
        "it": "Aumenta dinamicamente la dimensione delle icone in tempo reale",
        "es": "Aumenta el tamaño de los iconos dinámicamente",
        "fr": "Agrandit dynamiquement les icônes",
        "ca": "Augmenta la mida de les icones dinàmicament"
    },
    "Install Themes": {
        "zh_CN": "安装主题",
        "it": "Installa temi",
        "es": "Instalar temas",
        "fr": "Installer des thèmes",
        "ca": "Instal·la temes"
    },
    "Install WayPlank Theme": {
        "zh_CN": "安装 WayPlank 主题",
        "it": "Installa tema WayPlank",
        "es": "Instalar tema de WayPlank",
        "fr": "Installer un thème WayPlank",
        "ca": "Instal·la tema de WayPlank"
    },
    "Install theme archives (.zip, .tar.gz) and manage custom dock themes": {
        "zh_CN": "安装主题压缩包 (.zip, .tar.gz) 并管理自定义停靠栏主题",
        "it": "Installa archivi di temi (.zip, .tar.gz) e gestisci temi personalizzati",
        "es": "Instalar temas (.zip, .tar.gz) y gestionar temas personalizados",
        "fr": "Installer des archives de thèmes (.zip, .tar.gz) et gérer les thèmes personnalisés",
        "ca": "Instal·la arxius de temes (.zip, .tar.gz) i gestiona temes personalitzats"
    },
    "Interactions and gestures on application icons, drawers and docklets": {
        "zh_CN": "应用程序图标、抽屉及 Docklet 插件的交互与手势指南",
        "it": "Interazioni e gesti su icone di applicazioni, cassetti e docklet",
        "es": "Interacciones y gestos en iconos de aplicaciones, cajones y docklets",
        "fr": "Interactions et gestes sur les icônes d'applications, tiroirs et docklets",
        "ca": "Interaccions i gestos en icones d'aplicacions, calaixos i docklets"
    },
    "Launch app; if running, raises or opens Multi-Window Cards": {
        "zh_CN": "启动应用；若已运行，则置顶激活或展开多窗口平铺卡片",
        "it": "Avvia app; se in esecuzione, porta in primo piano o apre le schede multifinestra",
        "es": "Inicia la app; si está abierta, la trae al frente o abre tarjetas multiventana",
        "fr": "Lance l'app ; si ouverte, l'amène au premier plan ou ouvre les cartes multi-fenêtres",
        "ca": "Inicia l'aplicació; si s'executa, passa a primer pla o obre les targetes multifinestra"
    },
    "Left Click": {
        "zh_CN": "左键单击",
        "it": "Clic sinistro",
        "es": "Clic izquierdo",
        "fr": "Clic gauche",
        "ca": "Clic esquerre"
    },
    "Left Click (2+ windows)": {
        "zh_CN": "左键单击 (2个及以上窗口)",
        "it": "Clic sinistro (2+ finestre)",
        "es": "Clic izquierdo (2+ ventanas)",
        "fr": "Clic gauche (2+ fenêtres)",
        "ca": "Clic esquerre (2 o més finestres)"
    },
    "Left Click on Folder Drawer": {
        "zh_CN": "左键单击文件夹抽屉",
        "it": "Clic sinistro sul cassetto cartelle",
        "es": "Clic izquierdo en el cajón de carpetas",
        "fr": "Clic gauche sur le tiroir de dossiers",
        "ca": "Clic esquerre al calaix de carpetes"
    },
    "Loading weather...": {
        "zh_CN": "正在加载天气...",
        "it": "Caricamento meteo...",
        "es": "Cargando el tiempo...",
        "fr": "Chargement de la météo...",
        "ca": "S'està carregant el temps..."
    },
    "Location not found": {
        "zh_CN": "未找到位置",
        "it": "Posizione non trovata",
        "es": "Ubicación no encontrada",
        "fr": "Emplacement introuvable",
        "ca": "No s'ha trobat la ubicació"
    },
    "Location not found. Please choose from suggestions or leave blank.": {
        "zh_CN": "未找到指定位置。请从候选建议中挑选或留空自动检测。",
        "it": "Posizione non trovata. Scegli dai suggerimenti o lascia vuoto.",
        "es": "Ubicación no encontrada. Elija de las sugerencias o deje en blanco.",
        "fr": "Emplacement introuvable. Choisissez parmi les suggestions ou laissez vide.",
        "ca": "No s'ha trobat la ubicació. Trieu de les suggerències o deixeu-ho en blanc."
    },
    "Lock Screen": {
        "zh_CN": "锁定屏幕",
        "it": "Blocca schermo",
        "es": "Bloquear pantalla",
        "fr": "Verrouiller l'écran",
        "ca": "Bloca la pantalla"
    },
    "Lock the current session": {
        "zh_CN": "锁定当前桌面会话",
        "it": "Blocca la sessione corrente",
        "es": "Bloquea la sesión actual",
        "fr": "Verrouille la session actuelle",
        "ca": "Bloca la sessió actual"
    },
    "Log Out": {
        "zh_CN": "注销",
        "it": "Termina sessione",
        "es": "Cerrar sesión",
        "fr": "Fermer la session",
        "ca": "Tanca la sessió"
    },
    "Log Out of Session?": {
        "zh_CN": "注销当前用户会话？",
        "it": "Terminare la sessione?",
        "es": "¿Cerrar sesión?",
        "fr": "Fermer la session ?",
        "ca": "Voleu tancar la sessió?"
    },
    "Log _Out...": {
        "zh_CN": "注销(_O)...",
        "it": "Termina sessi_one...",
        "es": "Cerrar sesió_n...",
        "fr": "_Fermer la session...",
        "ca": "_Tanca la sessió..."
    },
    "Log out of the current session": {
        "zh_CN": "退出并注销当前用户会话",
        "it": "Termina la sessione corrente",
        "es": "Cerrar la sesión actual",
        "fr": "Fermer la session actuelle",
        "ca": "Tanca la sessió actual"
    },
    "Logged in as": {
        "zh_CN": "当前登录用户",
        "it": "Connesso come",
        "es": "Conectado como",
        "fr": "Connecté en tant que",
        "ca": "Connectat com a"
    },
    "Mainly clear": {
        "zh_CN": "晴间多云",
        "it": "Prevalentemente sereno",
        "es": "Mayormente despejado",
        "fr": "Généralement dégagé",
        "ca": "Principalment clar"
    },
    "Media Player": {
        "zh_CN": "媒体播放器",
        "it": "Lettore multimediale",
        "es": "Reproductor multimedia",
        "fr": "Lecteur multimédia",
        "ca": "Reproductor multimèdia"
    },
    "Media Player (%s)": {
        "zh_CN": "媒体播放器 (%s)",
        "it": "Lettore multimediale (%s)",
        "es": "Reproductor multimedia (%s)",
        "fr": "Lecteur multimédia (%s)",
        "ca": "Reproductor multimèdia (%s)"
    },
    "Media Player (Inactive)": {
        "zh_CN": "媒体播放器 (未激活)",
        "it": "Lettore multimediale (Inattivo)",
        "es": "Reproductor multimedia (Inactivo)",
        "fr": "Lecteur multimédia (Inactif)",
        "ca": "Reproductor multimèdia (inactiu)"
    },
    "Middle Click (or Ctrl + Left)": {
        "zh_CN": "中键单击 (或 Ctrl + 左键)",
        "it": "Clic centrale (o Ctrl + Sinistro)",
        "es": "Clic central (o Ctrl + Izquierdo)",
        "fr": "Clic milieu (ou Ctrl + Gauche)",
        "ca": "Clic del mig (o Ctrl + Esquerre)"
    },
    "Middle Click on MPRIS": {
        "zh_CN": "中键单击媒体播放器",
        "it": "Clic centrale su MPRIS",
        "es": "Clic central en MPRIS",
        "fr": "Clic milieu sur MPRIS",
        "ca": "Clic del mig a MPRIS"
    },
    "Minimized": {
        "zh_CN": "已最小化",
        "it": "Ridotta a icona",
        "es": "Minimizada",
        "fr": "Minimisée",
        "ca": "Minimitzada"
    },
    "Mouse Actions": {
        "zh_CN": "鼠标与手势操作",
        "it": "Azioni del mouse",
        "es": "Acciones del ratón",
        "fr": "Actions de la souris",
        "ca": "Accions del ratolí"
    },
    "Mouse Scroll on App": {
        "zh_CN": "在应用图标上滚动鼠标滚轮",
        "it": "Rotellina del mouse sull'app",
        "es": "Rueda del ratón sobre la app",
        "fr": "Molette de la souris sur l'app",
        "ca": "Roda del ratolí sobre l'aplicació"
    },
    "Mouse Scroll on Brightness": {
        "zh_CN": "在亮度图标上滚动滚轮",
        "it": "Rotellina del mouse sulla luminosità",
        "es": "Rueda del ratón sobre el brillo",
        "fr": "Molette de la souris sur la luminosité",
        "ca": "Roda del ratolí sobre la brillantor"
    },
    "Mouse Scroll on Dock Body": {
        "zh_CN": "在停靠栏空白底板上滚动滚轮",
        "it": "Rotellina del mouse sul corpo del dock",
        "es": "Rueda del ratón sobre el dock",
        "fr": "Molette de la souris sur le corps du dock",
        "ca": "Roda del ratolí sobre el cos del dock"
    },
    "Mouse Scroll on MPRIS": {
        "zh_CN": "在媒体播放器上滚动滚轮",
        "it": "Rotellina del mouse su MPRIS",
        "es": "Rueda del ratón sobre MPRIS",
        "fr": "Molette de la souris sur MPRIS",
        "ca": "Roda del ratolí a MPRIS"
    },
    "Mouse Scroll on Volume": {
        "zh_CN": "在音量图标上滚动滚轮",
        "it": "Rotellina del mouse sul volume",
        "es": "Rueda del ratón sobre el volumen",
        "fr": "Molette de la souris sur le volume",
        "ca": "Roda del ratolí sobre el volum"
    },
    "Network": {
        "zh_CN": "网络",
        "it": "Rete",
        "es": "Red",
        "fr": "Réseau",
        "ca": "Xarxa"
    },
    "Network: Disconnected": {
        "zh_CN": "网络: 已断开",
        "it": "Rete: Disconnessa",
        "es": "Red: Desconectada",
        "fr": "Réseau : Déconnecté",
        "ca": "Xarxa: Desconnectada"
    },
    "No Removable Devices": {
        "zh_CN": "无移动存储设备",
        "it": "Nessun dispositivo rimovibile",
        "es": "No hay dispositivos extraíbles",
        "fr": "Aucun périphérique amovible",
        "ca": "Cap dispositiu extraïble"
    },
    "No forecast data available": {
        "zh_CN": "暂无天气预报数据",
        "it": "Nessun dato di previsione disponibile",
        "es": "No hay datos de pronóstico disponibles",
        "fr": "Aucune donnée de prévision disponible",
        "ca": "No hi ha dades de previsió disponibles"
    },
    "No internet connection": {
        "zh_CN": "无网络连接",
        "it": "Nessuna connessione Internet",
        "es": "Sin conexión a Internet",
        "fr": "Pas de connexion Internet",
        "ca": "Sense connexió a Internet"
    },
    "No removable devices connected": {
        "zh_CN": "没有连接的可移动设备",
        "it": "Nessun dispositivo rimovibile connesso",
        "es": "No hay dispositivos extraíbles conectados",
        "fr": "Aucun périphérique amovible connecté",
        "ca": "No hi ha cap dispositiu extraïble connectat"
    },
    "No valid WayPlank/Plank theme found in the selected file.\\nA valid theme must contain a 'dock.theme' configuration file.": {
        "zh_CN": "选定的文件中未找到有效的 WayPlank/Plank 主题。\\n有效主题必须包含 'dock.theme' 配置文件。",
        "it": "Nessun tema WayPlank/Plank valido trovato nel file selezionato.\\nUn tema valido deve contenere un file di configurazione 'dock.theme'.",
        "es": "No se encontró ningún tema válido de WayPlank/Plank en el archivo.\\nUn tema válido debe contener un archivo de configuración 'dock.theme'.",
        "fr": "Aucun thème WayPlank/Plank valide trouvé dans le fichier sélectionné.\\nUn thème valide doit contenir un fichier 'dock.theme'.",
        "ca": "No s'ha trobat cap tema de WayPlank/Plank vàlid al fitxer seleccionat.\\nUn tema vàlid ha de contenir un fitxer de configuració 'dock.theme'."
    },
    "OK": {
        "zh_CN": "确定",
        "it": "OK",
        "es": "Aceptar",
        "fr": "OK",
        "ca": "D'acord"
    },
    "Offline": {
        "zh_CN": "离线",
        "it": "Non in linea",
        "es": "Desconectado",
        "fr": "Hors ligne",
        "ca": "Fora de línia"
    },
    "One-shot sort in Free mode: [Plank] -> [Folders] -> [Docklets] -> [Apps] -> [Trash]": {
        "zh_CN": "自由模式下一键自动排序: [Plank] -> [文件夹] -> [插件] -> [应用] -> [回收站]",
        "it": "Ordinamento rapido in modalità libera: [Plank] -> [Cartelle] -> [Docklet] -> [App] -> [Cestino]",
        "es": "Ordenación con un clic en modo libre: [Plank] -> [Carpetas] -> [Docklets] -> [Apps] -> [Papelera]",
        "fr": "Tri rapide en mode libre : [Plank] -> [Dossiers] -> [Docklets] -> [Apps] -> [Corbeille]",
        "ca": "Ordenació d'un sol clic en mode lliure: [Plank] -> [Carpetes] -> [Docklets] -> [Aplicacions] -> [Paperera]"
    },
    "Open": {
        "zh_CN": "打开",
        "it": "Apri",
        "es": "Abrir",
        "fr": "Ouvrir",
        "ca": "Obre"
    },
    "Open Containing _Folder": {
        "zh_CN": "打开所在文件夹(_F)",
        "it": "Apri _cartella contenitrice",
        "es": "Abrir carpeta c_ontenedora",
        "fr": "Ouvrir le d_ossier parent",
        "ca": "Obre la carpeta c_ontenidora"
    },
    "Open Developer Tools submenu (inspect launcher, config, theme)": {
        "zh_CN": "打开开发者工具子菜单 (检查启动器属性、配置目录及主题源码)",
        "it": "Apri sottomenu Strumenti di sviluppo (ispeziona lanciatore, config, tema)",
        "es": "Abrir submenú de Herramientas de desarrollo (inspeccionar lanzador, config, tema)",
        "fr": "Ouvrir le sous-menu Outils de développement (inspecter lanceur, config, thème)",
        "ca": "Obre el submenú d'eines de desenvolupament (inspecciona llançador, configuració, tema)"
    },
    "Open Screenshots Folder": {
        "zh_CN": "打开截屏保存目录",
        "it": "Apri cartella schermate",
        "es": "Abrir carpeta de capturas",
        "fr": "Ouvrir le dossier des captures",
        "ca": "Obre la carpeta de captures"
    },
    "Open config folder": {
        "zh_CN": "打开配置目录",
        "it": "Apri cartella di configurazione",
        "es": "Abrir carpeta de configuración",
        "fr": "Ouvrir le dossier de configuration",
        "ca": "Obre la carpeta de configuració"
    },
    "Open context menu (Recent Documents, Quicklists, Keep in Dock, Change Icon, Shortcuts & Gestures, Preferences)": {
        "zh_CN": "打开右键菜单 (最近打开文档、快捷操作列表、固定至 Dock、更改图标、快捷键与手势、首选项)",
        "it": "Apri menu contestuale (Documenti recenti, Quicklist, Mantieni nel dock, Cambia icona, Scorciatoie e gesti, Preferenze)",
        "es": "Abrir menú contextual (Documentos recientes, Listas rápidas, Mantener en dock, Cambiar icono, Atajos y gestos, Preferencias)",
        "fr": "Ouvrir le menu contextuel (Documents récents, Listes rapides, Garder dans le dock, Changer d'icône, Raccourcis et gestes, Préférences)",
        "ca": "Obre el menú contextual (Documents recents, Llistes ràpides, Mantén al dock, Canvia la icona, Dreceres i gestos, Preferències)"
    },
    "Open current theme file": {
        "zh_CN": "打开当前主题文件",
        "it": "Apri file del tema corrente",
        "es": "Abrir archivo del tema actual",
        "fr": "Ouvrir le fichier du thème actuel",
        "ca": "Obre el fitxer del tema actual"
    },
    "Open dark-themed categorized smart application menu": {
        "zh_CN": "打开深色高质感分类智能应用抽屉",
        "it": "Apri menu applicazioni intelligente categorizzato con tema scuro",
        "es": "Abrir menú inteligente de aplicaciones categorizado con tema oscuro",
        "fr": "Ouvrir le menu intelligent des applications classées par catégorie avec thème sombre",
        "ca": "Obre el menú d'aplicacions categoritzat amb tema fosc"
    },
    "Open dock preferences menu directly, even over an icon": {
        "zh_CN": "直接呼出停靠栏首选项菜单 (即使鼠标位于图标上方)",
        "it": "Apri direttamente il menu delle preferenze del dock, anche sopra un'icona",
        "es": "Abrir directamente el menú de preferencias del dock, incluso sobre un icono",
        "fr": "Ouvrir directement les préférences du dock, même sur une icône",
        "ca": "Obre directament el menú de preferències del dock, fins i tot sobre una icona"
    },
    "Open dock preferences menu from any empty dock area or separator": {
        "zh_CN": "从停靠栏任意空白区域或分隔线上打开首选项设置",
        "it": "Apri il menu delle preferenze da qualsiasi area vuota o separatore del dock",
        "es": "Abrir el menú de preferencias desde cualquier área vacía o separador",
        "fr": "Ouvrir les préférences du dock depuis un espace vide ou un séparateur",
        "ca": "Obre el menú de preferències del dock des de qualsevol àrea buida o separador"
    },
    "Open dockitem file": {
        "zh_CN": "打开 dockitem 文件",
        "it": "Apri file dockitem",
        "es": "Abrir archivo dockitem",
        "fr": "Ouvrir le fichier dockitem",
        "ca": "Obre el fitxer dockitem"
    },
    "Open launcher file": {
        "zh_CN": "打开启动器 .desktop 文件",
        "it": "Apri file del lanciatore",
        "es": "Abrir archivo del lanzador",
        "fr": "Ouvrir le fichier du lanceur",
        "ca": "Obre el fitxer del llançador"
    },
    "Open the dropped file directly with that application": {
        "zh_CN": "直接使用该应用程序打开拖放的文件",
        "it": "Apri il file rilasciato direttamente con quell'applicazione",
        "es": "Abrir el archivo soltado directamente con esa aplicación",
        "fr": "Ouvrir le fichier déposé directement avec cette application",
        "ca": "Obre el fitxer arrossegat directament amb aquesta aplicació"
    },
    "Open this interactive guide directly from any item context menu": {
        "zh_CN": "从任意图标右键菜单中快速打开此交互式指南",
        "it": "Apri questa guida interattiva direttamente dal menu contestuale di qualsiasi elemento",
        "es": "Abrir esta guía interactiva directamente desde el menú contextual de cualquier elemento",
        "fr": "Ouvrir ce guide interactif depuis le menu contextuel de n'importe quel élément",
        "ca": "Obre aquesta guia interactiva directament des de qualsevol menú contextual"
    },
    "Organizing, pinning, reordering and interacting with dock items": {
        "zh_CN": "停靠栏图标的整理、固定、重排及深度交互",
        "it": "Organizzazione, blocco, riordino e interazione con gli elementi del dock",
        "es": "Organización, fijación, reordenación e interacción con elementos del dock",
        "fr": "Organisation, épinglage, réorganisation et interaction avec les éléments du dock",
        "ca": "Organització, ancoratge, reordenació i interacció amb els elements del dock"
    },
    "Overcast": {
        "zh_CN": "阴天",
        "it": "Coperto",
        "es": "Nublado",
        "fr": "Couvert",
        "ca": "Encobert"
    },
    "P_revious Track": {
        "zh_CN": "上一曲(_R)",
        "it": "Traccia p_recedente",
        "es": "Pista a_nterior",
        "fr": "Piste p_récédente",
        "ca": "Pista a_nterior"
    },
    "Partially supported compositors: %s": {
        "zh_CN": "部分支持的混成器: %s",
        "it": "Compositori parzialmente supportati: %s",
        "es": "Compositores parcialmente compatibles: %s",
        "fr": "Compositeurs partiellement pris en charge : %s",
        "ca": "Compositors parcialment compatibles: %s"
    },
    "Partially supported compositors: none": {
        "zh_CN": "部分支持的混成器: 无",
        "it": "Compositori parzialmente supportati: nessuno",
        "es": "Compositores parcialmente compatibles: ninguno",
        "fr": "Compositeurs partiellement pris en charge : aucun",
        "ca": "Compositors parcialment compatibles: cap"
    },
    "Partly cloudy": {
        "zh_CN": "多云",
        "it": "Parzialmente nuvoloso",
        "es": "Parcialmente nublado",
        "fr": "Partiellement nuageux",
        "ca": "Parcialment ennuvolat"
    },
    "Pin a new application or folder drawer to the dock": {
        "zh_CN": "固定新的应用程序或文件夹抽屉至停靠栏",
        "it": "Fissa una nuova applicazione o cassetto cartelle nel dock",
        "es": "Fija una nueva aplicación o cajón de carpetas en el dock",
        "fr": "Épingler une nouvelle application ou un tiroir de dossiers au dock",
        "ca": "Ancora una aplicació o calaix de carpetes al dock"
    },
    "Play / _Pause": {
        "zh_CN": "播放 / 暂停(_P)",
        "it": "Riproduci / _Pausa",
        "es": "Reproducir / _Pausa",
        "fr": "Lecture / _Pause",
        "ca": "Reprodueix / _Pausa"
    },
    "Play or pause media playback": {
        "zh_CN": "播放或暂停多媒体播放",
        "it": "Riproduci o metti in pausa la riproduzione multimediale",
        "es": "Reproducir o pausar la reproducción de medios",
        "fr": "Lire ou mettre en pause la lecture multimédia",
        "ca": "Reprodueix o posa en pausa la reproducció"
    },
    "Please verify internet connection or location in Settings.": {
        "zh_CN": "请在设置中检查网络连接或城市位置是否正确。",
        "it": "Verifica la connessione a Internet o la posizione nelle Impostazioni.",
        "es": "Compruebe la conexión a Internet o la ubicación en Ajustes.",
        "fr": "Veuillez vérifier la connexion Internet ou l'emplacement dans les Paramètres.",
        "ca": "Comproveu la connexió a Internet o la ubicació a la configuració."
    },
    "Power off the computer": {
        "zh_CN": "彻底关闭计算机电源",
        "it": "Spegni il computer",
        "es": "Apagar el ordenador",
        "fr": "Éteindre l'ordinateur",
        "ca": "Apaga l'ordinador"
    },
    "Preferences": {
        "zh_CN": "首选项",
        "it": "Preferenze",
        "es": "Preferencias",
        "fr": "Préférences",
        "ca": "Preferències"
    },
    "Preferences -> Theme Manager": {
        "zh_CN": "首选项 -> 主题管理器",
        "it": "Preferenze -> Gestore temi",
        "es": "Preferencias -> Gestor de temas",
        "fr": "Préférences -> Gestionnaire de thèmes",
        "ca": "Preferències -> Gestor de temes"
    },
    "Preferences Icon (Accordion)": {
        "zh_CN": "首选项图标 (折叠风琴)",
        "it": "Icona preferenze (Fisarmonica)",
        "es": "Icono de preferencias (Acordeón)",
        "fr": "Icône des préférences (Accordéon)",
        "ca": "Icona de preferències (Acordió)"
    },
    "Preferences...": {
        "zh_CN": "首选项...",
        "it": "Preferenze...",
        "es": "Preferencias...",
        "fr": "Préférences...",
        "ca": "Preferències..."
    },
    "Print info to stdout": {
        "zh_CN": "打印信息至控制台",
        "it": "Stampa info su stdout",
        "es": "Imprimir información en stdout",
        "fr": "Afficher les infos sur stdout",
        "ca": "Imprimeix informació a stdout"
    },
    "Put computer into low-power sleep mode": {
        "zh_CN": "将计算机置于低功耗睡眠待机状态",
        "it": "Metti il computer in modalità di sospensione a basso consumo",
        "es": "Poner el ordenador en modo de suspensión de bajo consumo",
        "fr": "Mettre l'ordinateur en mode veille basse consommation",
        "ca": "Posa l'ordinador en mode de baix consum"
    },
    "Quit": {
        "zh_CN": "退出",
        "it": "Esci",
        "es": "Salir",
        "fr": "Quitter",
        "ca": "Surt"
    },
    "Quit WayPlank": {
        "zh_CN": "退出 WayPlank",
        "it": "Esci da WayPlank",
        "es": "Salir de WayPlank",
        "fr": "Quitter WayPlank",
        "ca": "Surt de WayPlank"
    },
    "Rain": {
        "zh_CN": "降雨",
        "it": "Pioggia",
        "es": "Lluvia",
        "fr": "Pluie",
        "ca": "Pluja"
    },
    "Rain showers": {
        "zh_CN": "阵雨",
        "it": "Rovesci di pioggia",
        "es": "Chubascos",
        "fr": "Averses de pluie",
        "ca": "Ruixats"
    },
    "Real-time automatic Light/Dark mode switching on KDE and GNOME": {
        "zh_CN": "深度联动 KDE Plasma 与 GNOME 实时自动跟随系统明暗深浅模式",
        "it": "Passaggio automatico in tempo reale tra modalità Chiara e Scura su KDE e GNOME",
        "es": "Cambio automático en tiempo real entre modo Claro y Oscuro en KDE y GNOME",
        "fr": "Basculement automatique en temps réel entre mode Clair et Sombre sur KDE et GNOME",
        "ca": "Canvi automàtic en temps real de mode clar/fosc a KDE i GNOME"
    },
    "Reboot the operating system": {
        "zh_CN": "重启操作系统",
        "it": "Riavvia il sistema operativo",
        "es": "Reiniciar el sistema operativo",
        "fr": "Redémarrer le système d'exploitation",
        "ca": "Reinicia el sistema operatiu"
    },
    "Recent Files": {
        "zh_CN": "最近打开的文件",
        "it": "File recenti",
        "es": "Archivos recientes",
        "fr": "Fichiers récents",
        "ca": "Fitxers recents"
    },
    "Refresh Weather": {
        "zh_CN": "刷新天气",
        "it": "Aggiorna meteo",
        "es": "Actualizar tiempo",
        "fr": "Actualiser la météo",
        "ca": "Actualitza el temps"
    },
    "Removable Drives": {
        "zh_CN": "可移动驱动器",
        "it": "Unità rimovibili",
        "es": "Unidades extraíbles",
        "fr": "Lecteurs amovibles",
        "ca": "Unitats extraïbles"
    },
    "Removable Drives (%u mounted)": {
        "zh_CN": "可移动驱动器 (%u 个已挂载)",
        "it": "Unità rimovibili (%u montate)",
        "es": "Unidades extraíbles (%u montadas)",
        "fr": "Lecteurs amovibles (%u montés)",
        "ca": "Unitats extraïbles (%u muntades)"
    },
    "Removable Drives (None connected)": {
        "zh_CN": "可移动驱动器 (未连接)",
        "it": "Unità rimovibili (Nessuna connessa)",
        "es": "Unidades extraíbles (Ninguna conectada)",
        "fr": "Lecteurs amovibles (Aucun connecté)",
        "ca": "Unitats extraïbles (cap connectada)"
    },
    "Reorder strictly within category bounds; Preferences anchor stays locked": {
        "zh_CN": "严格在所属分类界限内重排；首选项锚点始终保持锁定",
        "it": "Riordina rigorosamente entro i confini della categoria; le Preferenze restano bloccate",
        "es": "Reordena dentro de los límites de categoría; el ancla de Preferencias permanece fija",
        "fr": "Réorganisation strictement par catégorie ; l'ancre des Préférences reste verrouillée",
        "ca": "Reordena estrictament dins dels límits de cada categoria; l'ancoratge de preferències roman bloquejat"
    },
    "Report a _Bug Online...": {
        "zh_CN": "在线报告问题(_B)...",
        "it": "Segnala un _bug online...",
        "es": "Informar de un _error en línea...",
        "fr": "Signaler une _anomalie en ligne...",
        "ca": "Informa d'un _error en línia..."
    },
    "Requires touching the physical screen edge (1px) to reveal the dock, preventing accidental triggers; when disabled, reveals 10px before the edge for fluid unhiding": {
        "zh_CN": "需触及屏幕物理最边缘 (1px) 方可呼出停靠栏以防误触；关闭后则在边缘 10px 范围内平滑灵敏呼出",
        "it": "Richiede di toccare il bordo fisico dello schermo (1px) per mostrare il dock, evitando aperture accidentali; se disabilitato, mostra 10px prima per una comparsa fluida",
        "es": "Requiere tocar el borde físico de la pantalla (1px) para mostrar el dock, evitando aperturas accidentales; deshabilitado muestra 10px antes",
        "fr": "Nécessite de toucher le bord de l'écran (1px) pour afficher le dock ; désactivé, réapparaît à 10px pour plus de fluidité",
        "ca": "Requereix tocar la vora física de la pantalla (1px) per mostrar el dock, evitant activacions accidentals; quan està desactivat, es mostra 10px abans de la vora per a una aparició fluida"
    },
    "Restart": {
        "zh_CN": "重启",
        "it": "Riavvia",
        "es": "Reiniciar",
        "fr": "Redémarrer",
        "ca": "Reinicia"
    },
    "Restart System": {
        "zh_CN": "重启系统",
        "it": "Riavvia sistema",
        "es": "Reiniciar sistema",
        "fr": "Redémarrer le système",
        "ca": "Reinicia el sistema"
    },
    "Restart System?": {
        "zh_CN": "重启计算机系统？",
        "it": "Riavviare il sistema?",
        "es": "¿Reiniciar sistema?",
        "fr": "Redémarrer le système ?",
        "ca": "Voleu reiniciar el sistema?"
    },
    "Restore Default": {
        "zh_CN": "恢复默认",
        "it": "Ripristina predefinito",
        "es": "Restaurar predeterminado",
        "fr": "Restaurer par défaut",
        "ca": "Restaura per defecte"
    },
    "Revert to the original default icon": {
        "zh_CN": "恢复原始默认图标",
        "it": "Ripristina l'icona predefinita originale",
        "es": "Volver al icono predeterminado original",
        "fr": "Revenir à l'icône par défaut d'origine",
        "ca": "Restaura la icona predeterminada original"
    },
    "Right Click -> Change Icon...": {
        "zh_CN": "右键单击 -> 更改图标...",
        "it": "Clic destro -> Cambia icona...",
        "es": "Clic derecho -> Cambiar icono...",
        "fr": "Clic droit -> Changer d'icône...",
        "ca": "Clic dret -> Canvia la icona..."
    },
    "Right Click -> Shortcuts & Gestures": {
        "zh_CN": "右键单击 -> 快捷键与手势",
        "it": "Clic destro -> Scorciatoie e gesti",
        "es": "Clic derecho -> Atajos y gestos",
        "fr": "Clic droit -> Raccourcis et gestes",
        "ca": "Clic dret -> Dreceres i gestos"
    },
    "Right Click on Any Item": {
        "zh_CN": "在任何项目上右键单击",
        "it": "Clic destro su qualsiasi elemento",
        "es": "Clic derecho en cualquier elemento",
        "fr": "Clic droit sur n'importe quel élément",
        "ca": "Clic dret sobre qualsevol element"
    },
    "Right Click on space / separator": {
        "zh_CN": "在底板空白处或分隔线上右键单击",
        "it": "Clic destro su spazio vuoto / separatore",
        "es": "Clic derecho en espacio / separador",
        "fr": "Clic droit sur un espace / séparateur",
        "ca": "Clic dret a l'espai buit o separador"
    },
    "Running": {
        "zh_CN": "运行中",
        "it": "In esecuzione",
        "es": "En ejecución",
        "fr": "En cours d'exécution",
        "ca": "En execució"
    },
    "Safe to Remove": {
        "zh_CN": "可安全移除",
        "it": "Sicuro da rimuovere",
        "es": "Seguro para retirar",
        "fr": "Peut être retiré en toute sécurité",
        "ca": "Segur d'extreure"
    },
    "Save & Apply": {
        "zh_CN": "保存并应用",
        "it": "Salva e applica",
        "es": "Guardar y aplicar",
        "fr": "Enregistrer et appliquer",
        "ca": "Desa i aplica"
    },
    "Screen Brightness": {
        "zh_CN": "屏幕亮度",
        "it": "Luminosità schermo",
        "es": "Brillo de pantalla",
        "fr": "Luminosité de l'écran",
        "ca": "Brillantor de la pantalla"
    },
    "Screen Brightness: %d%%": {
        "zh_CN": "屏幕亮度: %d%%",
        "it": "Luminosità schermo: %d%%",
        "es": "Brillo de pantalla: %d%%",
        "fr": "Luminosité de l'écran : %d%%",
        "ca": "Brillantor de la pantalla: %d%%"
    },
    "Screenshot": {
        "zh_CN": "截屏",
        "it": "Schermata",
        "es": "Captura de pantalla",
        "fr": "Capture d'écran",
        "ca": "Captura de pantalla"
    },
    "Scroll on Overflow active: %dpx preserved": {
        "zh_CN": "超限平滑翻页已激活: 保留图标大小 %dpx",
        "it": "Scorrimento per overflow attivo: %dpx preservati",
        "es": "Desplazamiento por desbordamiento activo: %dpx preservados",
        "fr": "Défilement actif : %dpx préservés",
        "ca": "Desplaçament per desbordament actiu: %dpx conservats"
    },
    "Search theme icons (e.g. browser, folder, games, edit)...": {
        "zh_CN": "搜索主题图标库 (例如: browser, folder, games, edit)...",
        "it": "Cerca icone del tema (es. browser, cartella, giochi, modifica)...",
        "es": "Buscar iconos del tema (ej. navegador, carpeta, juegos, edición)...",
        "fr": "Rechercher des icônes de thème (ex. navigateur, dossier, jeux, édition)...",
        "ca": "Cerca icones del tema (p. ex. navegador, carpeta, jocs, edició)..."
    },
    "Select": {
        "zh_CN": "选择",
        "it": "Seleziona",
        "es": "Seleccionar",
        "fr": "Sélectionner",
        "ca": "Selecciona"
    },
    "Select Icon File": {
        "zh_CN": "选择图标文件",
        "it": "Seleziona file icona",
        "es": "Seleccionar archivo de icono",
        "fr": "Sélectionner un fichier d'icône",
        "ca": "Selecciona el fitxer d'icona"
    },
    "Select icon for: ": {
        "zh_CN": "选择图标: ",
        "it": "Seleziona icona per: ",
        "es": "Seleccionar icono para: ",
        "fr": "Sélectionner une icône pour : ",
        "ca": "Selecciona la icona per a: "
    },
    "Session": {
        "zh_CN": "电源与会话",
        "it": "Sessione",
        "es": "Sesión",
        "fr": "Session",
        "ca": "Sessió"
    },
    "Session & Power": {
        "zh_CN": "电源与会话",
        "it": "Sessione e alimentazione",
        "es": "Sesión y energía",
        "fr": "Session et alimentation",
        "ca": "Sessió i energia"
    },
    "Session &amp; Power": {
        "zh_CN": "电源与会话",
        "it": "Sessione e alimentazione",
        "es": "Sesión y energía",
        "fr": "Session et alimentation",
        "ca": "Sessió i energia"
    },
    "Session / Power": {
        "zh_CN": "电源与会话",
        "it": "Sessione / Alimentazione",
        "es": "Sesión / Energía",
        "fr": "Session / Alimentation",
        "ca": "Sessió / Energia"
    },
    "Session _Dialog...": {
        "zh_CN": "会话管理窗口(_D)...",
        "it": "_Finestra di sessione...",
        "es": "_Diálogo de sesión...",
        "fr": "_Dialogue de session...",
        "ca": "_Diàleg de sessió..."
    },
    "Set Location...": {
        "zh_CN": "设置城市位置...",
        "it": "Imposta posizione...",
        "es": "Establecer ubicación...",
        "fr": "Définir l'emplacement...",
        "ca": "Defineix la ubicació..."
    },
    "Shift + Left Click": {
        "zh_CN": "Shift + 左键单击",
        "it": "Maiusc + Clic sinistro",
        "es": "Mayús + Clic izquierdo",
        "fr": "Maj + Clic gauche",
        "ca": "Maj + Clic esquerre"
    },
    "Shortcuts & Tools": {
        "zh_CN": "快捷键与实用工具",
        "it": "Scorciatoie e strumenti",
        "es": "Atajos y herramientas",
        "fr": "Raccourcis et outils",
        "ca": "Dreceres i eines"
    },
    "Show Desktop": {
        "zh_CN": "显示桌面",
        "it": "Mostra scrivania",
        "es": "Mostrar escritorio",
        "fr": "Afficher le bureau",
        "ca": "Mostra l'escriptori"
    },
    "Shut Down": {
        "zh_CN": "关机",
        "it": "Arresta sistema",
        "es": "Apagar",
        "fr": "Éteindre",
        "ca": "Atura"
    },
    "Shut Down Computer?": {
        "zh_CN": "关闭计算机？",
        "it": "Spegnere il computer?",
        "es": "¿Apagar ordenador?",
        "fr": "Éteindre l'ordinateur ?",
        "ca": "Voleu apagar l'ordinador?"
    },
    "Shut Down System": {
        "zh_CN": "关闭计算机",
        "it": "Spegni sistema",
        "es": "Apagar el sistema",
        "fr": "Éteindre le système",
        "ca": "Atura el sistema"
    },
    "Skip to next or previous media track": {
        "zh_CN": "切歌至下一曲或上一曲",
        "it": "Passa alla traccia multimediale successiva o precedente",
        "es": "Saltar a la pista multimedia siguiente o anterior",
        "fr": "Passer à la piste multimédia suivante ou précédente",
        "ca": "Salta a la pista següent o anterior"
    },
    "Smoothly scroll overflowing dock items when capacity is reached": {
        "zh_CN": "图标超出屏幕容纳上限时开启平滑滚轮横向/纵向翻页",
        "it": "Scorri fluidamente gli elementi in eccesso quando il dock raggiunge la capienza",
        "es": "Desplaza suavemente los iconos cuando se supera la capacidad del dock",
        "fr": "Faites défiler fluidement les éléments en débordement lorsque la capacité est atteinte",
        "ca": "Desplaça suaument els elements del dock quan s'arriba a la capacitat màxima"
    },
    "Snow": {
        "zh_CN": "降雪",
        "it": "Neve",
        "es": "Nieve",
        "fr": "Neige",
        "ca": "Neu"
    },
    "Snow grains": {
        "zh_CN": "雪粒",
        "it": "Granuli di neve",
        "es": "Granos de nieve",
        "fr": "Grains de neige",
        "ca": "Neu granulada"
    },
    "Snow showers": {
        "zh_CN": "阵雪",
        "it": "Rovesci di neve",
        "es": "Chubascos de nieve",
        "fr": "Averses de neige",
        "ca": "Ruixats de neu"
    },
    "Spring-loaded hover (500ms) brings target window to foreground": {
        "zh_CN": "悬停 500 毫秒自动置顶唤醒目标窗口 (悬停弹窗)",
        "it": "La sospensione elastica (500ms) porta la finestra di destinazione in primo piano",
        "es": "La pausa sobre el icono (500ms) trae la ventana objetivo al frente",
        "fr": "Le survol prolongé (500ms) amène la fenêtre cible au premier plan",
        "ca": "L'espera emergent (500 ms) porta la finestra objectiu a primer pla"
    },
    "Suspend": {
        "zh_CN": "待机/睡眠",
        "it": "Sospendi",
        "es": "Suspender",
        "fr": "Mettre en veille",
        "ca": "Suspèn"
    },
    "Switch User": {
        "zh_CN": "切换用户",
        "it": "Cambia utente",
        "es": "Cambiar de usuario",
        "fr": "Changer d'utilisateur",
        "ca": "Canvia d'usuari"
    },
    "Switch to Celsius (°C)": {
        "zh_CN": "切换到摄氏度 (°C)",
        "it": "Passa a Celsius (°C)",
        "es": "Cambiar a Celsius (°C)",
        "fr": "Passer en Celsius (°C)",
        "ca": "Canvia a Celsius (°C)"
    },
    "Switch to Fahrenheit (°F)": {
        "zh_CN": "切换到华氏度 (°F)",
        "it": "Passa a Fahrenheit (°F)",
        "es": "Cambiar a Fahrenheit (°F)",
        "fr": "Passer en Fahrenheit (°F)",
        "ca": "Canvia a Fahrenheit (°F)"
    },
    "Switch to another user or login screen": {
        "zh_CN": "切换到其他系统用户或锁屏登录界面",
        "it": "Passa a un altro utente o alla schermata di accesso",
        "es": "Cambiar a otro usuario o pantalla de inicio de sesión",
        "fr": "Changer d'utilisateur ou écran de connexion",
        "ca": "Canvia a un altre usuari o a la pantalla d'inici de sessió"
    },
    "System Monitor": {
        "zh_CN": "系统监控",
        "it": "Monitor di sistema",
        "es": "Monitor del sistema",
        "fr": "Moniteur système",
        "ca": "Monitor del sistema"
    },
    "System themes cannot be deleted": {
        "zh_CN": "系统预置核心主题无法删除",
        "it": "I temi di sistema non possono essere eliminati",
        "es": "Los temas del sistema no se pueden eliminar",
        "fr": "Les thèmes système ne peuvent pas être supprimés",
        "ca": "Els temes del sistema no es poden suprimir"
    },
    "System: %d%% | CPU: %d%% | RAM: %d%% (%.1f / %.1f GB) | Disk: %d%%": {
        "zh_CN": "系统: %d%% | CPU: %d%% | 内存: %d%% (%.1f / %.1f GB) | 磁盘: %d%%",
        "it": "Sistema: %d%% | CPU: %d%% | RAM: %d%% (%.1f / %.1f GB) | Disco: %d%%",
        "es": "Sistema: %d%% | CPU: %d%% | RAM: %d%% (%.1f / %.1f GB) | Disco: %d%%",
        "fr": "Système : %d%% | CPU : %d%% | RAM : %d%% (%.1f / %.1f Go) | Disque : %d%%",
        "ca": "Sistema: %d%% | CPU: %d%% | RAM: %d%% (%.1f / %.1f GB) | Disc: %d%%"
    },
    "Target icon size: %dpx.\\n'Scroll on Overflow' is enabled in Behaviour: icons will never shrink, and the dock smoothly scrolls with mouse wheel when items exceed screen space.": {
        "zh_CN": "目标图标大小: %dpx。\\n行为设置中已启用 '超限平滑翻页'：图标绝不会被动缩小，当项目超出屏幕空间时可通过滚轮平滑浏览。",
        "it": "Dimensione icone: %dpx.\\n'Scorrimento per overflow' è abilitato in Comportamento: le icone non si rimpiccioliranno mai e il dock scorre fluidamente con la rotellina quando gli elementi superano lo spazio.",
        "es": "Tamaño de iconos: %dpx.\\n'Desplazamiento por desbordamiento' activado: los iconos nunca se encogerán y el dock se desplazará suavemente.",
        "fr": "Taille d'icône : %dpx.\\n'Défilement par débordement' activé : les icônes ne rétréciront jamais et le dock défile fluidement avec la molette.",
        "ca": "Mida d'icona objectiu: %dpx.\\nEl 'Desplaçament per desbordament' està activat a Comportament: les icones mai no s'encongiran i el dock es desplaçarà suaument amb la roda del ratolí quan els elements superin l'espai de pantalla."
    },
    "Target icon size: %dpx.\\nFits comfortably on screen (screen capacity limit: %dpx before auto-shrinking activates).": {
        "zh_CN": "目标图标大小: %dpx。\\n完全舒适适应屏幕 (触发自动缩小的临界上限为 %dpx)。",
        "it": "Dimensione icone: %dpx.\\nEntra perfettamente nello schermo (limite capienza: %dpx prima che si attivi il rimpicciolimento automatico).",
        "es": "Tamaño de iconos: %dpx.\\nCabe cómodamente en pantalla (límite: %dpx antes de encogerse automáticamente).",
        "fr": "Taille d'icône : %dpx.\\nTient confortablement sur l'écran (limite : %dpx avant rétrécissement automatique).",
        "ca": "Mida d'icona objectiu: %dpx.\\nCap còmodament a la pantalla (límit de capacitat de la pantalla: %dpx abans que s'activi la reducció automàtica)."
    },
    "The archive contains multiple themes. Select which ones to install:": {
        "zh_CN": "该压缩包包含多个主题。请选择要安装的主题:",
        "it": "L'archivio contiene più temi. Seleziona quali installare:",
        "es": "El archivo contiene varios temas. Seleccione cuáles instalar:",
        "fr": "L'archive contient plusieurs thèmes. Sélectionnez ceux à installer :",
        "ca": "L'arxiu conté diversos temes. Seleccioneu quins voleu instal·lar:"
    },
    "Theme Archives (*.zip, *.tar.gz, *.tar.xz, *.theme)": {
        "zh_CN": "主题压缩包 (*.zip, *.tar.gz, *.tar.xz, *.theme)",
        "it": "Archivi di temi (*.zip, *.tar.gz, *.tar.xz, *.theme)",
        "es": "Archivos de temas (*.zip, *.tar.gz, *.tar.xz, *.theme)",
        "fr": "Archives de thèmes (*.zip, *.tar.gz, *.tar.xz, *.theme)",
        "ca": "Arxius de temes (*.zip, *.tar.gz, *.tar.xz, *.theme)"
    },
    "Thunderstorm": {
        "zh_CN": "雷阵雨",
        "it": "Temporale",
        "es": "Tormenta",
        "fr": "Orage",
        "ca": "Tempesta"
    },
    "Thunderstorm with hail": {
        "zh_CN": "雷阵雨伴有冰雹",
        "it": "Temporale con grandine",
        "es": "Tormenta con granizo",
        "fr": "Orage avec grêle",
        "ca": "Tempesta amb pedra"
    },
    "Today": {
        "zh_CN": "今天",
        "it": "Oggi",
        "es": "Hoy",
        "fr": "Aujourd'hui",
        "ca": "Avui"
    },
    "Trash": {
        "zh_CN": "回收站",
        "it": "Cestino",
        "es": "Papelera",
        "fr": "Corbeille",
        "ca": "Paperera"
    },
    "Trash (%u items)": {
        "zh_CN": "回收站 (%u 项)",
        "it": "Cestino (%u elementi)",
        "es": "Papelera (%u elementos)",
        "fr": "Corbeille (%u éléments)",
        "ca": "Paperera (%u elements)"
    },
    "Trash (1 item)": {
        "zh_CN": "回收站 (1 项)",
        "it": "Cestino (1 elemento)",
        "es": "Papelera (1 elemento)",
        "fr": "Corbeille (1 élément)",
        "ca": "Paperera (1 element)"
    },
    "Trash (Empty)": {
        "zh_CN": "回收站 (空)",
        "it": "Cestino (Vuoto)",
        "es": "Papelera (Vacía)",
        "fr": "Corbeille (Vide)",
        "ca": "Paperera (Buida)"
    },
    "Un_mute": {
        "zh_CN": "取消静音(_M)",
        "it": "Riattiva a_udio",
        "es": "Des_activar silencio",
        "fr": "Réactiver le _son",
        "ca": "Desactiva el silenci(_M)"
    },
    "Units:": {
        "zh_CN": "温度单位:",
        "it": "Unità:",
        "es": "Unidades:",
        "fr": "Unités :",
        "ca": "Unitats:"
    },
    "Unpin / remove launcher from dock (with poof animation)": {
        "zh_CN": "取消固定 / 将启动器拖出停靠栏删除 (带有青烟消散动画)",
        "it": "Sblocca / rimuovi lanciatore dal dock (con animazione di fumo)",
        "es": "Desanclar / quitar lanzador del dock (con animación de humo)",
        "fr": "Détacher / retirer le lanceur du dock (avec animation de fumée)",
        "ca": "Desancora / elimina el llançador del dock (amb animació d'esvaïment)"
    },
    "Updating weather...": {
        "zh_CN": "正在更新天气...",
        "it": "Aggiornamento meteo in corso...",
        "es": "Actualizando el tiempo...",
        "fr": "Mise à jour de la météo...",
        "ca": "S'està actualitzant el temps..."
    },
    "User Guide...": {
        "zh_CN": "用户指南...",
        "it": "Guida utente...",
        "es": "Guía de usuario...",
        "fr": "Guide de l'utilisateur...",
        "ca": "Guia d'usuari..."
    },
    "Violent rain showers": {
        "zh_CN": "狂暴阵雨",
        "it": "Nubifragio / Rovesci violenti",
        "es": "Chubascos torrenciales",
        "fr": "Averses violentes",
        "ca": "Ruixats violents"
    },
    "Volume": {
        "zh_CN": "音量",
        "it": "Volume",
        "es": "Volumen",
        "fr": "Volume",
        "ca": "Volum"
    },
    "Volume: %d%%": {
        "zh_CN": "音量: %d%%",
        "it": "Volume: %d%%",
        "es": "Volumen: %d%%",
        "fr": "Volume : %d%%",
        "ca": "Volum: %d%%"
    },
    "Volume: %d%% (Muted)": {
        "zh_CN": "音量: %d%% (静音)",
        "it": "Volume: %d%% (Disattivato)",
        "es": "Volumen: %d%% (Silenciado)",
        "fr": "Volume : %d%% (Muet)",
        "ca": "Volum: %d%% (Silenciat)"
    },
    "WayPlank Preferences": {
        "zh_CN": "WayPlank 首选项",
        "it": "Preferenze di WayPlank",
        "es": "Preferencias de WayPlank",
        "fr": "Préférences de WayPlank",
        "ca": "Preferències de WayPlank"
    },
    "WayPlank Shortcuts & Gestures": {
        "zh_CN": "WayPlank 快捷键与手势指南",
        "it": "Scorciatoie e gesti di WayPlank",
        "es": "Atajos y gestos de WayPlank",
        "fr": "Raccourcis et gestes de WayPlank",
        "ca": "Dreceres i gestos de WayPlank"
    },
    "Weather": {
        "zh_CN": "天气",
        "it": "Meteo",
        "es": "Tiempo",
        "fr": "Météo",
        "ca": "Temps"
    },
    "Weather Forecast": {
        "zh_CN": "天气预报",
        "it": "Previsioni meteo",
        "es": "Pronóstico del tiempo",
        "fr": "Prévisions météo",
        "ca": "Previsió del temps"
    },
    "Weather Location Settings": {
        "zh_CN": "天气城市与位置设置",
        "it": "Impostazioni posizione meteo",
        "es": "Ajustes de ubicación del tiempo",
        "fr": "Paramètres d'emplacement météo",
        "ca": "Configuració de la ubicació del temps"
    },
    "Wi-Fi: %s (%d%%)": {
        "zh_CN": "Wi-Fi: %s (%d%%)",
        "it": "Wi-Fi: %s (%d%%)",
        "es": "Wi-Fi: %s (%d%%)",
        "fr": "Wi-Fi : %s (%d%%)",
        "ca": "Wi-Fi: %s (%d%%)"
    },
    "Wi-Fi: %s (%d%%) - %s": {
        "zh_CN": "Wi-Fi: %s (%d%%) - %s",
        "it": "Wi-Fi: %s (%d%%) - %s",
        "es": "Wi-Fi: %s (%d%%) - %s",
        "fr": "Wi-Fi : %s (%d%%) - %s",
        "ca": "Wi-Fi: %s (%d%%) - %s"
    },
    "Wired Connection": {
        "zh_CN": "有线网络连接",
        "it": "Connessione via cavo",
        "es": "Conexión cableada",
        "fr": "Connexion filaire",
        "ca": "Connexió per cable"
    },
    "Workspace filtering is not yet supported under Wayland": {
        "zh_CN": "工作区独立过滤功能在当前 Wayland 规范下暂未开放",
        "it": "Il filtraggio per spazio di lavoro non è ancora supportato su Wayland",
        "es": "El filtrado por espacio de trabajo aún no es compatible en Wayland",
        "fr": "Le filtrage par espace de travail n'est pas encore pris en charge sous Wayland",
        "ca": "El filtratge per àrea de treball encara no és compatible amb Wayland"
    },
    "_About": {
        "zh_CN": "关于(_A)",
        "it": "Inform_azioni",
        "es": "_Acerca de",
        "fr": "À _propos",
        "ca": "_Quant a"
    },
    "_Analog Clock": {
        "zh_CN": "模拟时钟(_A)",
        "it": "Orologio _analogico",
        "es": "Reloj _analógico",
        "fr": "Horloge _analogique",
        "ca": "Rellotge _analògic"
    },
    "_Appearance...": {
        "zh_CN": "外观(_A)...",
        "it": "_Aspetto...",
        "es": "_Apariencia...",
        "fr": "_Apparence...",
        "ca": "_Aparença..."
    },
    "_Audio Settings...": {
        "zh_CN": "声音设置(_A)...",
        "it": "Impostazioni _audio...",
        "es": "Ajustes de _audio...",
        "fr": "Paramètres _audio...",
        "ca": "Configuració d'_àudio..."
    },
    "_Battery": {
        "zh_CN": "电池(_B)",
        "it": "_Batteria",
        "es": "_Batería",
        "fr": "_Batterie",
        "ca": "_Bateria"
    },
    "_Behaviour...": {
        "zh_CN": "行为(_B)...",
        "it": "_Comportamento...",
        "es": "_Comportamiento...",
        "fr": "Com_portement...",
        "ca": "Com_portament..."
    },
    "_Browse File...": {
        "zh_CN": "浏览文件(_B)...",
        "it": "_Sfoglia file...",
        "es": "_Examinar archivo...",
        "fr": "_Parcourir les fichiers...",
        "ca": "_Navega pel fitxer..."
    },
    "_CPU / RAM Monitor": {
        "zh_CN": "CPU / 内存监控(_C)",
        "it": "Monitor _CPU / RAM",
        "es": "Monitor _CPU / RAM",
        "fr": "Moniteur _CPU / RAM",
        "ca": "Monitor _CPU / RAM"
    },
    "_Cancel": {
        "zh_CN": "取消(_C)",
        "it": "_Annulla",
        "es": "_Cancelar",
        "fr": "_Annuler",
        "ca": "_Cancel·la"
    },
    "_Close": {
        "zh_CN": "关闭(_C)",
        "it": "_Chiudi",
        "es": "_Cerrar",
        "fr": "_Fermer",
        "ca": "_Tanca"
    },
    "_Copy Time": {
        "zh_CN": "复制时间(_C)",
        "it": "_Copia ora",
        "es": "_Copiar hora",
        "fr": "_Copier l'heure",
        "ca": "_Copia l'hora"
    },
    "_Digital Clock": {
        "zh_CN": "数字时钟(_D)",
        "it": "Orologio _digitale",
        "es": "Reloj _digital",
        "fr": "Horloge _numérique",
        "ca": "Rellotge _digital"
    },
    "_Display Settings...": {
        "zh_CN": "显示设置(_D)...",
        "it": "Impostazioni _schermo...",
        "es": "Ajustes de _pantalla...",
        "fr": "Paramètres d'_affichage...",
        "ca": "Configuració de la _pantalla..."
    },
    "_Docklets": {
        "zh_CN": "插件(_D)",
        "it": "_Docklet",
        "es": "_Docklets",
        "fr": "_Docklets",
        "ca": "_Docklets"
    },
    "_Docklets...": {
        "zh_CN": "插件(_D)...",
        "it": "_Docklet...",
        "es": "_Docklets...",
        "fr": "_Docklets...",
        "ca": "_Docklets..."
    },
    "_Empty Trash": {
        "zh_CN": "清空回收站(_E)",
        "it": "_Svuota cestino",
        "es": "_Vaciar papelera",
        "fr": "_Vider la corbeille",
        "ca": "_Buida la paperera"
    },
    "_Install": {
        "zh_CN": "安装(_I)",
        "it": "_Installa",
        "es": "_Instalar",
        "fr": "_Installer",
        "ca": "_Instal·la"
    },
    "_Keep in Dock": {
        "zh_CN": "固定到 Dock(_K)",
        "it": "_Mantieni nel dock",
        "es": "_Mantener en el dock",
        "fr": "_Garder dans le dock",
        "ca": "_Mantén al dock"
    },
    "_Lock Screen": {
        "zh_CN": "锁定屏幕(_L)",
        "it": "B_locca schermo",
        "es": "B_loquear pantalla",
        "fr": "Verroui_ller l'écran",
        "ca": "B_loca la pantalla"
    },
    "_Media Player": {
        "zh_CN": "媒体播放器(_M)",
        "it": "Lettore _multimediale",
        "es": "Reproductor _multimedia",
        "fr": "Lecteur _multimédia",
        "ca": "Reproductor _multimèdia"
    },
    "_Mute": {
        "zh_CN": "静音(_M)",
        "it": "_Silenzioso",
        "es": "_Silenciar",
        "fr": "_Muet",
        "ca": "_Silencia"
    },
    "_Network / Wi-Fi": {
        "zh_CN": "网络 / Wi-Fi(_N)",
        "it": "_Rete / Wi-Fi",
        "es": "_Red / Wi-Fi",
        "fr": "_Réseau / Wi-Fi",
        "ca": "_Xarxa / Wi-Fi"
    },
    "_Network Settings...": {
        "zh_CN": "网络设置(_N)...",
        "it": "Impostazioni _rete...",
        "es": "Ajustes de _red...",
        "fr": "Paramètres _réseau...",
        "ca": "Configuració de _xarxa..."
    },
    "_New Window": {
        "zh_CN": "新建窗口(_N)",
        "it": "_Nuova finestra",
        "es": "_Nueva ventana",
        "fr": "_Nouvelle fenêtre",
        "ca": "_Nova finestra"
    },
    "_Next Track": {
        "zh_CN": "下一曲(_N)",
        "it": "Traccia s_uccessiva",
        "es": "Pista s_iguiente",
        "fr": "Piste s_uivante",
        "ca": "Pista s_egüent"
    },
    "_Open": {
        "zh_CN": "打开(_O)",
        "it": "_Apri",
        "es": "_Abrir",
        "fr": "_Ouvrir",
        "ca": "_Obre"
    },
    "_Open Trash": {
        "zh_CN": "打开回收站(_O)",
        "it": "_Apri cestino",
        "es": "_Abrir papelera",
        "fr": "_Ouvrir la corbeille",
        "ca": "_Obre la paperera"
    },
    "_Open in File Browser": {
        "zh_CN": "在文件管理器中打开(_O)",
        "it": "_Apri nel gestore file",
        "es": "_Abrir en el explorador de archivos",
        "fr": "_Ouvrir dans le gestionnaire de fichiers",
        "ca": "_Obre al gestor de fitxers"
    },
    "_Power Settings...": {
        "zh_CN": "电源设置(_P)...",
        "it": "Impostazioni _alimentazione...",
        "es": "Ajustes de _energía...",
        "fr": "Paramètres d'_alimentation...",
        "ca": "Configuració d'_energia..."
    },
    "_Preferences": {
        "zh_CN": "首选项(_P)",
        "it": "_Preferenze",
        "es": "_Preferencias",
        "fr": "_Préférences",
        "ca": "_Preferències"
    },
    "_Preferences...": {
        "zh_CN": "首选项(_P)...",
        "it": "_Preferenze...",
        "es": "_Preferencias...",
        "fr": "_Préférences...",
        "ca": "_Preferències..."
    },
    "_Quit": {
        "zh_CN": "退出(_Q)",
        "it": "_Esci",
        "es": "_Salir",
        "fr": "_Quitter",
        "ca": "_Surt"
    },
    "_Removable Drives": {
        "zh_CN": "可移动驱动器(_R)",
        "it": "Unità _rimovibili",
        "es": "Unidades _extraíbles",
        "fr": "Lecteurs _amovibles",
        "ca": "Unitats _extraïbles"
    },
    "_Remove from Dock": {
        "zh_CN": "从 Dock 移除(_R)",
        "it": "_Rimuovi dal dock",
        "es": "_Eliminar del dock",
        "fr": "_Retirer du dock",
        "ca": "_Elimina del dock"
    },
    "_Restart...": {
        "zh_CN": "重启(_R)...",
        "it": "_Riavvia...",
        "es": "_Reiniciar...",
        "fr": "_Redémarrer...",
        "ca": "_Reinicia..."
    },
    "_Screen Brightness": {
        "zh_CN": "屏幕亮度(_S)",
        "it": "Luminosità _schermo",
        "es": "Brillo de _pantalla",
        "fr": "Luminosité de l'_écran",
        "ca": "Brillantor de la _pantalla"
    },
    "_Screenshot": {
        "zh_CN": "截屏(_S)",
        "it": "_Schermata",
        "es": "_Captura de pantalla",
        "fr": "_Capture d'écran",
        "ca": "_Captura de pantalla"
    },
    "_Session / Power": {
        "zh_CN": "电源与会话(_S)",
        "it": "_Sessione / Alimentazione",
        "es": "_Sesión / Energía",
        "fr": "_Session / Alimentation",
        "ca": "_Sessió / Energia"
    },
    "_Shortcuts & Gestures...": {
        "zh_CN": "快捷键与手势(_S)...",
        "it": "_Scorciatoie e gesti...",
        "es": "_Atajos y gestos...",
        "fr": "_Raccourcis et gestes...",
        "ca": "_Dreceres i gestos..."
    },
    "_Show / Hide Desktop": {
        "zh_CN": "显示 / 隐藏桌面(_S)",
        "it": "_Mostra / Nascondi scrivania",
        "es": "_Mostrar / Ocultar escritorio",
        "fr": "_Afficher / Masquer le bureau",
        "ca": "_Mostra / Amaga l'escriptori"
    },
    "_Show Desktop": {
        "zh_CN": "显示桌面(_S)",
        "it": "_Mostra scrivania",
        "es": "_Mostrar escritorio",
        "fr": "_Afficher le bureau",
        "ca": "_Mostra l'escriptori"
    },
    "_Shut Down...": {
        "zh_CN": "关机(_S)...",
        "it": "_Arresta...",
        "es": "_Apagar...",
        "fr": "_Éteindre...",
        "ca": "_Atura..."
    },
    "_Suspend": {
        "zh_CN": "待机/睡眠(_S)",
        "it": "_Sospendi",
        "es": "_Suspender",
        "fr": "Mettre en _veille",
        "ca": "_Suspèn"
    },
    "_Switch User...": {
        "zh_CN": "切换用户(_S)...",
        "it": "_Cambia utente...",
        "es": "_Cambiar de usuario...",
        "fr": "_Changer d'utilisateur...",
        "ca": "_Canvia d'usuari..."
    },
    "_System Monitor...": {
        "zh_CN": "系统监控(_S)...",
        "it": "_Monitor di sistema...",
        "es": "_Monitor del sistema...",
        "fr": "_Moniteur système...",
        "ca": "_Monitor del sistema..."
    },
    "_Trash": {
        "zh_CN": "回收站(_T)",
        "it": "_Cestino",
        "es": "_Papelera",
        "fr": "_Corbeille",
        "ca": "_Paperera"
    },
    "_Volume Control": {
        "zh_CN": "音量控制(_V)",
        "it": "Controllo _volume",
        "es": "Control de _volumen",
        "fr": "Contrôle du _volume",
        "ca": "Control de _volum"
    },
    "_Weather Forecast": {
        "zh_CN": "天气预报(_W)",
        "it": "Previsioni _meteo",
        "es": "Pronóstico del _tiempo",
        "fr": "Prévisions _météo",
        "ca": "Previsió del _temps"
    },
    "e.g. Rome, London, New York...": {
        "zh_CN": "例如: 北京, 上海, 广州, 深圳, 罗马...",
        "it": "es. Roma, Londra, New York...",
        "es": "ej. Madrid, Barcelona, Londres...",
        "fr": "ex. Paris, Lyon, Londres...",
        "ca": "p. ex. Barcelona, Roma, Londres..."
    },
    "translator-credits": {
        "zh_CN": "史有虎 (IFtiger-hu) <2212363803@qq.com>",
        "it": "Sergio Melas <sergiomelas@gmail.com>",
        "es": "Sergio Melas <sergiomelas@gmail.com>",
        "fr": "Sergio Melas <sergiomelas@gmail.com>",
        "ca": "Sergio Melas <sergiomelas@gmail.com>"
    },
    "ℹ️ Leave blank (or click ✖ to clear) to re-detect your location using IP.": {
        "zh_CN": "ℹ️ 留空 (或点击 ✖ 清空) 可通过公网 IP 自动重新检测所在城市。",
        "it": "ℹ️ Lascia vuoto (o fai clic su ✖) per rilevare nuovamente la posizione tramite IP.",
        "es": "ℹ️ Deje en blanco (o haga clic en ✖) para redetectar la ubicación por IP.",
        "fr": "ℹ️ Laissez vide (ou cliquez sur ✖) pour redétecter l'emplacement par IP.",
        "ca": "ℹ️ Deixeu-ho en blanc (o feu clic a ✖ per netejar) per redetectar la vostra ubicació mitjançant IP."
    },
    "⚙️ Location...": {
        "zh_CN": "⚙️ 设置城市...",
        "it": "⚙️ Posizione...",
        "es": "⚙️ Ubicación...",
        "fr": "⚙️ Emplacement...",
        "ca": "⚙️ Ubicació..."
    },
    "⚠️ Icon size set to %dpx, but clamped to %dpx by screen space.\\nIcons will auto-shrink to fit on screen.\\nTo unlock larger sizes without shrinking, enable 'Scroll on Overflow' in Behaviour.": {
        "zh_CN": "⚠️ 图标大小设定为 %dpx，但因屏幕空间不足被强制约束在 %dpx。\\n图标会自动缩小以容纳在屏幕内。\\n若要无视屏幕限制解锁更大图标尺寸，请在 '行为' 中启用 '超限平滑翻页'。",
        "it": "⚠️ Dimensione icone impostata a %dpx, ma limitata a %dpx dallo spazio.\\nLe icone si rimpiccioliscono automaticamente per entrare nello schermo.\\nPer sbloccare dimensioni maggiori, abilita 'Scorrimento per overflow' in Comportamento.",
        "es": "⚠️ Tamaño de icono establecido en %dpx, pero limitado a %dpx.\\nLos iconos se encogerán automáticamente.\\nPara desbloquear tamaños mayores, active 'Desplazamiento por desbordamiento'.",
        "fr": "⚠️ Taille d'icône réglée sur %dpx, mais limitée à %dpx.\\nLes icônes rétrécissent automatiquement.\\nPour débloquer de plus grandes tailles, activez le 'Défilement par débordement'.",
        "ca": "⚠️ Mida d'icona establerta a %dpx, però limitada a %dpx per l'espai de pantalla.\\nLes icones es reduiran automàticament per cabre a la pantalla.\\nPer desbloquejar mides més grans sense reducció, activeu 'Desplaçament per desbordament' a Comportament."
    },
    "⚠️ Limited to %dpx by screen space (auto-shrunk)": {
        "zh_CN": "⚠️ 受限于屏幕物理空间强制限制为 %dpx (自动缩小)",
        "it": "⚠️ Limitato a %dpx dallo spazio sullo schermo (rimpicciolito)",
        "es": "⚠️ Limitado a %dpx por el espacio en pantalla (auto-encogido)",
        "fr": "⚠️ Limité à %dpx par l'espace écran (rétrécissement auto)",
        "ca": "⚠️ Limitat a %dpx per l'espai de pantalla (reducció automàtica)"
    },
    "🔄 Refresh": {
        "zh_CN": "🔄 刷新",
        "it": "🔄 Aggiorna",
        "es": "🔄 Actualizar",
        "fr": "🔄 Actualiser",
        "ca": "🔄 Actualitza"
    }
}

languages = [
    {
        "code": "zh_CN",
        "name": "Chinese (Simplified)",
        "locale": "zh_CN.UTF-8",
        "team": "Chinese (Simplified) <zh_CN@li.org>",
        "plural": "nplurals=1; plural=0;\n",
        "author": "史有虎 (IFtiger-hu) <2212363803@qq.com>"
    },
    {
        "code": "it",
        "name": "Italian",
        "locale": "it_IT.UTF-8",
        "team": "Italian <it@li.org>",
        "plural": "nplurals=2; plural=(n != 1);\n",
        "author": "Sergio Melas <sergiomelas@gmail.com>"
    },
    {
        "code": "es",
        "name": "Spanish",
        "locale": "es_ES.UTF-8",
        "team": "Spanish <es@li.org>",
        "plural": "nplurals=2; plural=(n != 1);\n",
        "author": "Sergio Melas <sergiomelas@gmail.com>"
    },
    {
        "code": "fr",
        "name": "French",
        "locale": "fr_FR.UTF-8",
        "team": "French <fr@li.org>",
        "plural": "nplurals=2; plural=(n > 1);\n",
        "author": "Sergio Melas <sergiomelas@gmail.com>"
    },
    {
        "code": "ca",
        "name": "Catalan",
        "locale": "ca_ES.UTF-8",
        "team": "Catalan <ca@li.org>",
        "plural": "nplurals=2; plural=(n != 1);\n",
        "author": "Sergio Melas <sergiomelas@gmail.com>"
    }
]

norm_dict = {}
for k, v in translations.items():
    norm_dict[k] = v
    if "\\n" in k:
        norm_dict[k.replace("\\n", "\n")] = v
    if "\n" in k:
        norm_dict[k.replace("\n", "\\n")] = v

def format_po_string(s):
    escaped = s.replace('"', '\\"')
    if "\n" in escaped:
        lines = escaped.split("\n")
        res = 'msgstr ""\n'
        for i, l in enumerate(lines):
            if i < len(lines) - 1:
                res += f'"{l}\\n"\n'
            else:
                res += f'"{l}"'
        return res
    else:
        return f'msgstr "{escaped}"'

for lang_info in languages:
    code = lang_info["code"]
    po_path = f"po/{code}.po"
    subprocess.run(["rm", "-f", po_path], check=False)
    subprocess.run([
        "msginit", "--input=po/wayplank.pot", f"--output={po_path}",
        f"--locale={lang_info['locale']}", "--no-translator"
    ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    with open(po_path, "r", encoding="utf-8") as f:
        content = f.read()

    blocks = re.split(r'\n\n(?=#: )', content)
    header = blocks[0]
    new_blocks = [header]
    mapped = 0

    for b in blocks[1:]:
        m = re.search(r'msgid ((\"[^\n]*\"\n)+)msgstr ((\"[^\n]*\"\n?)+)', b)
        if m:
            lines = m.group(1).strip().splitlines()
            val = ''.join([line[1:-1] for line in lines])
            val = val.replace('\\"', '"').replace('\\n', '\n')

            if val in norm_dict and code in norm_dict[val]:
                t = norm_dict[val][code]
                new_msgstr = format_po_string(t)
                idx = b.find("msgstr")
                b_updated = b[:idx] + new_msgstr + "\n"
                new_blocks.append(b_updated.strip())
                mapped += 1
            else:
                new_blocks.append(b.strip())
        else:
            new_blocks.append(b.strip())

    with open(po_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(new_blocks) + "\n")

    res = subprocess.run(["msgfmt", "-c", "-v", po_path, "-o", "/dev/null"], capture_output=True, text=True)
    print(f"[{code}] {lang_info['name']}: {mapped} translated messages. ({res.stderr.strip()})")
