/* ==========================================================================
   Budapp Web - Main JavaScript Application Architecture
   Implements 100% Feature Parity with the Android Flutter App
   ========================================================================== */

(function () {
  'use strict';

  // State Store Keys
  const STORAGE_KEYS = {
    COMPANY: 'budapp_company_settings',
    QUOTES: 'budapp_quotes',
    SERVICES: 'budapp_services',
    THEME: 'budapp_theme_settings',
    AUTH: 'budapp_auth_session'
  };

  // Color Palette Definitions matching Flutter ThemeProvider
  const THEME_COLORS = [
    { name: 'Azul', light: '#3B82F6', dark: '#1D4ED8', hover: '#2563EB' },
    { name: 'Verde', light: '#10B981', dark: '#047857', hover: '#059669' },
    { name: 'Naranja', light: '#F97316', dark: '#C2410C', hover: '#EA580C' },
    { name: 'Púrpura', light: '#8B5CF6', dark: '#6D28D9', hover: '#7C3AED' },
    { name: 'Rosa', light: '#EC4899', dark: '#BE185D', hover: '#DB2777' },
    { name: 'Teal', light: '#14B8A6', dark: '#0F766E', hover: '#0D9488' },
    { name: 'Amarillo', light: '#FBBF24', dark: '#D97706', hover: '#D97706' }
  ];

  // Global App State
  let appState = {
    auth: {
      isAuthenticated: false,
      userEmail: '',
      isGuest: false
    },
    company: {
      name: '',
      address: '',
      phone: '',
      email: '',
      website: '',
      logoBase64: null
    },
    quotes: [],
    services: [],
    theme: {
      colorIndex: 0,
      isDark: false
    },
    activeTab: 'home',
    currentQuoteItems: [],
    editingQuoteId: null,
    historyFilters: {
      query: '',
      status: 'Todos',
      dateRange: null
    },
    servicesSearchQuery: '',
    isSignUpMode: false
  };

  /* ==========================================================================
     FIREBASE & CLOUD SYNC ARCHITECTURE
     ========================================================================== */
  const firebaseConfig = {
    apiKey: "AIzaSyCmBaNWCVu1cXP0F_-TnyA96Yg5NrZp-FY",
    authDomain: "mgz-app-98294.firebaseapp.com",
    projectId: "mgz-app-98294",
    storageBucket: "mgz-app-98294.firebasestorage.app",
    messagingSenderId: "562409321853",
    appId: "1:562409321853:web:955c45fefc8d8c98108814"
  };

  let auth = null;
  let db = null;

  function initFirebase() {
    try {
      if (typeof firebase !== 'undefined') {
        if (!firebase.apps.length) {
          firebase.initializeApp(firebaseConfig);
        }
        auth = firebase.auth();
        db = firebase.firestore();

        auth.onAuthStateChanged(async (user) => {
          if (user) {
            appState.auth.isAuthenticated = true;
            appState.auth.userEmail = user.email || '';
            appState.auth.uid = user.uid;
            appState.auth.isGuest = false;
            saveAuthToStorage();

            // Auto sync from cloud when authenticated
            await syncFromCloud(false);
          } else {
            if (!appState.auth.isGuest) {
              appState.auth.isAuthenticated = false;
              appState.auth.userEmail = '';
              appState.auth.uid = null;
              saveAuthToStorage();
            }
          }
          checkSessionState();
        });
      }
    } catch (e) {
      console.error("Firebase init error:", e);
    }
  }

  async function syncFromCloud(showNotifications = true) {
    if (!auth || !db || !auth.currentUser) return;
    const uid = auth.currentUser.uid;

    try {
      // 1. Company Settings
      const companyDoc = await db.collection('users').doc(uid).collection('company').doc('settings').get();
      if (companyDoc.exists) {
        const data = companyDoc.data();
        appState.company = {
          name: data.name || '',
          address: data.address || '',
          phone: data.phone || '',
          email: data.email || '',
          website: data.website || '',
          logoBase64: data.logoBase64 || null
        };
        localStorage.setItem(STORAGE_KEYS.COMPANY, JSON.stringify(appState.company));
      }

      // 2. Services
      const servicesSnap = await db.collection('users').doc(uid).collection('services').get();
      if (!servicesSnap.empty) {
        const fetchedServices = [];
        servicesSnap.forEach(doc => {
          fetchedServices.push(doc.data());
        });
        appState.services = fetchedServices;
        localStorage.setItem(STORAGE_KEYS.SERVICES, JSON.stringify(appState.services));
      }

      // 3. Quotes
      const quotesSnap = await db.collection('users').doc(uid).collection('quotes').get();
      if (!quotesSnap.empty) {
        const fetchedQuotes = [];
        quotesSnap.forEach(doc => {
          fetchedQuotes.push(doc.data());
        });
        fetchedQuotes.sort((a, b) => new Date(b.date) - new Date(a.date));
        appState.quotes = fetchedQuotes;
        localStorage.setItem(STORAGE_KEYS.QUOTES, JSON.stringify(appState.quotes));
      }

      renderAllViews();
      updateSyncBadge();

      if (showNotifications) {
        showToast('Datos restaurados desde la nube con éxito');
      }
    } catch (e) {
      console.error("Error downloading from cloud:", e);
      if (showNotifications) {
        showToast('Error al descargar datos de la nube: ' + e.message);
      }
    }
  }

  async function uploadToCloud(showNotifications = true) {
    if (!auth || !db || !auth.currentUser) return;
    const uid = auth.currentUser.uid;

    try {
      // 1. Company Settings
      await db.collection('users').doc(uid).collection('company').doc('settings').set({
        name: appState.company.name || '',
        address: appState.company.address || '',
        phone: appState.company.phone || '',
        email: appState.company.email || '',
        website: appState.company.website || '',
        logoBase64: appState.company.logoBase64 || null
      });

      // 2. Services (batch)
      if (appState.services.length > 0) {
        const servicesBatch = db.batch();
        appState.services.forEach(srv => {
          const docRef = db.collection('users').doc(uid).collection('services').doc(srv.id);
          servicesBatch.set(docRef, srv);
        });
        await servicesBatch.commit();
      }

      // 3. Quotes (batch)
      if (appState.quotes.length > 0) {
        const quotesBatch = db.batch();
        appState.quotes.forEach(q => {
          const docRef = db.collection('users').doc(uid).collection('quotes').doc(q.id);
          quotesBatch.set(docRef, q);
        });
        await quotesBatch.commit();
      }

      updateSyncBadge();
      if (showNotifications) {
        showToast('Datos respaldados en la nube con éxito');
      }
    } catch (e) {
      console.error("Error uploading to cloud:", e);
      if (showNotifications) {
        showToast('Error al respaldar datos: ' + e.message);
      }
    }
  }

  async function syncCompanyToCloud() {
    if (auth && db && auth.currentUser) {
      const uid = auth.currentUser.uid;
      try {
        await db.collection('users').doc(uid).collection('company').doc('settings').set({
          name: appState.company.name || '',
          address: appState.company.address || '',
          phone: appState.company.phone || '',
          email: appState.company.email || '',
          website: appState.company.website || '',
          logoBase64: appState.company.logoBase64 || null
        });
      } catch (e) { console.error("Error syncing company:", e); }
    }
  }

  async function syncServiceToCloud(service) {
    if (auth && db && auth.currentUser) {
      const uid = auth.currentUser.uid;
      try {
        await db.collection('users').doc(uid).collection('services').doc(service.id).set(service);
      } catch (e) { console.error("Error syncing service:", e); }
    }
  }

  async function deleteServiceFromCloud(serviceId) {
    if (auth && db && auth.currentUser) {
      const uid = auth.currentUser.uid;
      try {
        await db.collection('users').doc(uid).collection('services').doc(serviceId).delete();
      } catch (e) { console.error("Error deleting service from cloud:", e); }
    }
  }

  async function syncQuoteToCloud(quote) {
    if (auth && db && auth.currentUser) {
      const uid = auth.currentUser.uid;
      try {
        await db.collection('users').doc(uid).collection('quotes').doc(quote.id).set(quote);
      } catch (e) { console.error("Error syncing quote:", e); }
    }
  }

  async function deleteQuoteFromCloud(quoteId) {
    if (auth && db && auth.currentUser) {
      const uid = auth.currentUser.uid;
      try {
        await db.collection('users').doc(uid).collection('quotes').doc(quoteId).delete();
      } catch (e) { console.error("Error deleting quote from cloud:", e); }
    }
  }

  /* ==========================================================================
     INITIALIZATION & SESSION GATING
     ========================================================================== */
  function init() {
    loadStateFromStorage();
    setupTheme();
    setupEventListeners();
    initFirebase();

    // Check Authentication Gating
    checkSessionState();
  }

  function loadStateFromStorage() {
    // 0. Load Auth Session
    const savedAuth = localStorage.getItem(STORAGE_KEYS.AUTH);
    if (savedAuth) {
      try { appState.auth = JSON.parse(savedAuth); } catch (e) {}
    }

    // 1. Load Company Profile
    const savedCompany = localStorage.getItem(STORAGE_KEYS.COMPANY);
    if (savedCompany) {
      try { appState.company = JSON.parse(savedCompany); } catch (e) {}
    }

    // 2. Load Services (or seed defaults)
    const savedServices = localStorage.getItem(STORAGE_KEYS.SERVICES);
    if (savedServices) {
      try { appState.services = JSON.parse(savedServices); } catch (e) {}
    } else {
      appState.services = getInitialDefaultServices();
      saveServicesToStorage();
    }

    // 3. Load Quotes (or seed defaults)
    const savedQuotes = localStorage.getItem(STORAGE_KEYS.QUOTES);
    if (savedQuotes) {
      try { appState.quotes = JSON.parse(savedQuotes); } catch (e) {}
    } else {
      appState.quotes = getInitialDefaultQuotes();
      saveQuotesToStorage();
    }

    // 4. Load Theme Settings
    const savedTheme = localStorage.getItem(STORAGE_KEYS.THEME);
    if (savedTheme) {
      try { appState.theme = JSON.parse(savedTheme); } catch (e) {}
    }
  }

  function checkSessionState() {
    const welcomeView = document.getElementById('view-welcome');
    const appView = document.getElementById('app');

    if (appState.auth.isAuthenticated || appState.auth.isGuest) {
      // User has active session or guest mode
      if (welcomeView) welcomeView.style.display = 'none';
      if (appView) appView.style.display = 'flex';

      updateSyncBadge();
      renderAllViews();
      drawIncomeChartCanvas();
      window.addEventListener('resize', drawIncomeChartCanvas);
    } else {
      // No session -> Gate to Welcome / Login screen
      if (welcomeView) welcomeView.style.display = 'flex';
      if (appView) appView.style.display = 'none';
      resetWelcomeScreen();
    }
  }

  function resetWelcomeScreen() {
    const optionsBox = document.getElementById('welcome-options-box');
    const authBox = document.getElementById('welcome-auth-box');

    if (optionsBox) optionsBox.style.display = 'none';
    if (authBox) authBox.style.display = 'block';
  }

  function saveAuthToStorage() {
    localStorage.setItem(STORAGE_KEYS.AUTH, JSON.stringify(appState.auth));
  }

  function updateSyncBadge() {
    const badge = document.getElementById('sync-status-badge');
    const badgeText = document.getElementById('sync-status-text');
    const badgeIcon = document.getElementById('sync-icon');

    const userStatus = document.getElementById('cloud-user-status');
    const userEmail = document.getElementById('cloud-user-email');

    if (appState.auth.isAuthenticated) {
      if (badge) badge.className = 'badge-button cloud-badge connected';
      if (badgeText) badgeText.textContent = 'Nube';
      if (badgeIcon) badgeIcon.className = 'ri-cloud-line text-success';

      if (userStatus) userStatus.textContent = 'Sesión Iniciada (Firebase)';
      if (userEmail) userEmail.textContent = appState.auth.userEmail || 'usuario@empresa.com';
    } else {
      if (badge) badge.className = 'badge-button cloud-badge';
      if (badgeText) badgeText.textContent = 'Local';
      if (badgeIcon) badgeIcon.className = 'ri-cloud-off-line text-warning';

      if (userStatus) userStatus.textContent = 'Modo Local Offline (Invitado)';
      if (userEmail) userEmail.textContent = 'Los datos se guardan únicamente en el navegador actual.';
    }
  }

  function logoutUser() {
    if (confirm('¿Deseas cerrar sesión?')) {
      appState.auth = {
        isAuthenticated: false,
        userEmail: '',
        isGuest: false
      };
      saveAuthToStorage();
      checkSessionState();
      showToast('Sesión cerrada correctamente');
    }
  }

  function getInitialDefaultServices() {
    return [
      { id: '1', name: 'Formateo de PC / Laptop + S.O.', price: 25000, category: 'Soporte Técnico' },
      { id: '2', name: 'Mantenimiento Preventivo y Limpieza', price: 18000, category: 'Soporte Técnico' },
      { id: '3', name: 'Instalación de Punto de Red UTP', price: 32000, category: 'Redes y Conectividad' },
      { id: '4', name: 'Configuración Router / Access Point WiFi', price: 20000, category: 'Redes y Conectividad' },
      { id: '5', name: 'Instalación Cámara de Seguridad IP / CCTV', price: 45000, category: 'Seguridad' },
      { id: '6', name: 'Diagnóstico Técnico en Sitio', price: 15000, category: 'Sin categoría' }
    ];
  }

  function getInitialDefaultQuotes() {
    const today = new Date();
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 2);

    return [
      {
        id: '101',
        number: '0001',
        date: yesterday.toISOString(),
        clientName: 'Juan Carlos Gómez',
        clientPhone: '+54 9 11 4455-6677',
        clientAddress: 'Av. Corrientes 1420, CABA',
        items: [
          { name: 'Formateo de PC / Laptop + S.O.', price: 25000, quantity: 2 },
          { name: 'Configuración Router / Access Point WiFi', price: 20000, quantity: 1 }
        ],
        total: 70000,
        status: 'Aceptado',
        observations: 'Forma de pago: Transferencia bancaria. Garantía 3 meses.',
        discountReason: '',
        discountPercentage: 0
      },
      {
        id: '102',
        number: '0002',
        date: today.toISOString(),
        clientName: 'Empresa RTA S.A.',
        clientPhone: '+54 9 11 9988-7766',
        clientAddress: 'Calle San Martín 500',
        items: [
          { name: 'Instalación de Punto de Red UTP', price: 32000, quantity: 4 },
          { name: 'Instalación Cámara de Seguridad IP / CCTV', price: 45000, quantity: 2 }
        ],
        total: 218000,
        status: 'Pendiente',
        observations: 'Presupuesto válido por 15 días.',
        discountReason: 'Descuento volumen',
        discountPercentage: 5
      }
    ];
  }

  function saveCompanyToStorage() {
    localStorage.setItem(STORAGE_KEYS.COMPANY, JSON.stringify(appState.company));
    syncCompanyToCloud();
  }

  function saveQuotesToStorage() {
    localStorage.setItem(STORAGE_KEYS.QUOTES, JSON.stringify(appState.quotes));
  }

  function saveServicesToStorage() {
    localStorage.setItem(STORAGE_KEYS.SERVICES, JSON.stringify(appState.services));
  }

  function saveThemeToStorage() {
    localStorage.setItem(STORAGE_KEYS.THEME, JSON.stringify(appState.theme));
  }

  /* ==========================================================================
     THEME & STYLING LOGIC
     ========================================================================== */
  function setupTheme() {
    const htmlEl = document.documentElement;
    if (appState.theme.isDark) {
      htmlEl.setAttribute('data-theme', 'dark');
      document.getElementById('theme-toggle-icon').className = 'ri-sun-line';
    } else {
      htmlEl.setAttribute('data-theme', 'light');
      document.getElementById('theme-toggle-icon').className = 'ri-moon-line';
    }

    applyAccentColor(appState.theme.colorIndex);
    renderColorPalette();
  }

  function applyAccentColor(index) {
    if (index < 0 || index >= THEME_COLORS.length) index = 0;
    appState.theme.colorIndex = index;
    const color = THEME_COLORS[index];

    document.documentElement.style.setProperty('--color-accent', color.light);
    document.documentElement.style.setProperty('--color-accent-dark', color.dark);
    document.documentElement.style.setProperty('--color-accent-hover', color.hover);
    document.documentElement.style.setProperty('--color-accent-light', hexToRgba(color.light, 0.12));

    const selectedLabel = document.getElementById('selected-color-name');
    if (selectedLabel) {
      selectedLabel.textContent = `Color seleccionado: ${color.name}`;
    }

    saveThemeToStorage();
    drawIncomeChartCanvas();
  }

  function hexToRgba(hex, alpha) {
    let c = hex.replace('#', '');
    if (c.length === 3) c = c.split('').map(x => x + x).join('');
    const num = parseInt(c, 16);
    return `rgba(${(num >> 16) & 255}, ${(num >> 8) & 255}, ${num & 255}, ${alpha})`;
  }

  function renderColorPalette() {
    const container = document.getElementById('color-palette-container');
    if (!container) return;

    container.innerHTML = THEME_COLORS.map((col, index) => {
      const isSelected = appState.theme.colorIndex === index ? 'selected' : '';
      return `
        <div class="color-dot-wrap ${isSelected}" data-color-index="${index}" title="${col.name}">
          <div class="color-dot" style="background-color: ${col.light};"></div>
        </div>
      `;
    }).join('');

    container.querySelectorAll('.color-dot-wrap').forEach(el => {
      el.addEventListener('click', () => {
        const idx = parseInt(el.getAttribute('data-color-index'));
        applyAccentColor(idx);
        renderColorPalette();
      });
    });
  }

  /* ==========================================================================
     INCOME CHART CANVAS PAINTER
     Direct port of Flutter IncomeChartPainter
     ========================================================================== */
  function drawIncomeChartCanvas() {
    const canvas = document.getElementById('income-chart-canvas');
    if (!canvas) return;

    const parent = canvas.parentElement;
    canvas.width = parent.clientWidth;
    canvas.height = parent.clientHeight;

    const ctx = canvas.getContext('2d');
    const width = canvas.width;
    const height = canvas.height;

    ctx.clearRect(0, 0, width, height);

    // Smooth Bezier Curve Path
    ctx.beginPath();
    ctx.moveTo(0, height * 0.75);
    ctx.bezierCurveTo(
      width * 0.25, height * 0.85,
      width * 0.45, height * 0.35,
      width * 0.7, height * 0.55
    );
    ctx.bezierCurveTo(
      width * 0.85, height * 0.65,
      width * 0.95, height * 0.2,
      width, height * 0.25
    );

    // Create Gradient Fill
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, 'rgba(255, 255, 255, 0.15)');
    gradient.addColorStop(1, 'rgba(255, 255, 255, 0.0)');

    // Fill area below curve
    ctx.lineTo(width, height);
    ctx.lineTo(0, height);
    ctx.closePath();
    ctx.fillStyle = gradient;
    ctx.fill();

    // Re-draw stroke curve line
    ctx.beginPath();
    ctx.moveTo(0, height * 0.75);
    ctx.bezierCurveTo(
      width * 0.25, height * 0.85,
      width * 0.45, height * 0.35,
      width * 0.7, height * 0.55
    );
    ctx.bezierCurveTo(
      width * 0.85, height * 0.65,
      width * 0.95, height * 0.2,
      width, height * 0.25
    );
    ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)';
    ctx.lineWidth = 2.5;
    ctx.stroke();
  }

  /* ==========================================================================
     NAVIGATION & TAB ROUTING
     ========================================================================== */
  function switchTab(tabName) {
    appState.activeTab = tabName;

    // Update active nav items
    document.querySelectorAll('[data-tab]').forEach(el => {
      if (el.getAttribute('data-tab') === tabName) {
        el.classList.add('active');
      } else {
        el.classList.remove('active');
      }
    });

    // Update visible tab views
    document.querySelectorAll('.tab-view').forEach(view => {
      view.classList.remove('active');
    });
    const targetView = document.getElementById(`view-${tabName}`);
    if (targetView) targetView.classList.add('active');

    // Scroll to top of view
    window.scrollTo({ top: 0, behavior: 'smooth' });

    // Refresh view data
    renderAllViews();
  }

  /* ==========================================================================
     UI RENDERING ENGINE
     ========================================================================== */
  function renderAllViews() {
    renderHomeView();
    renderHistoryView();
    renderServicesView();
    renderSettingsView();
  }

  // Formatting Helpers
  function formatCurrency(amount) {
    return new Intl.NumberFormat('es-AR', {
      style: 'currency',
      currency: 'ARS',
      maximumFractionDigits: 0
    }).format(amount || 0);
  }

  function formatDate(isoString) {
    if (!isoString) return '';
    const date = new Date(isoString);
    const day = String(date.getDate()).padStart(2, '0');
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const year = date.getFullYear();
    return `${day}/${month}/${year}`;
  }

  function getTimeElapsed(isoString) {
    if (!isoString) return '';
    const diff = new Date() - new Date(isoString);
    const minutes = Math.floor(diff / (1000 * 60));
    const hours = Math.floor(diff / (1000 * 60 * 60));
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));

    if (days >= 365) return `Hace ${Math.floor(days/365)} año(s)`;
    if (days >= 30) return `Hace ${Math.floor(days/30)} mes(es)`;
    if (days > 0) return `Hace ${days} día(s)`;
    if (hours > 0) return `Hace ${hours} hora(s)`;
    if (minutes > 0) return `Hace ${minutes} minuto(s)`;
    return 'Hace un instante';
  }

  function formatLogoSrc(logoBase64) {
    if (!logoBase64) return '';
    if (logoBase64.startsWith('data:image/') || logoBase64.startsWith('http://') || logoBase64.startsWith('https://')) {
      return logoBase64;
    }
    return `data:image/png;base64,${logoBase64}`;
  }

  // 1. Render Dashboard (Inicio)
  function renderHomeView() {
    const comp = appState.company;
    const quotes = appState.quotes;

    // Company Header Info
    const companyNameEl = document.getElementById('dash-company-name');
    const companyDetailsEl = document.getElementById('dash-company-details');
    const logoContainer = document.getElementById('dash-company-logo');

    if (companyNameEl) companyNameEl.textContent = comp.name || 'Nombre de tu Empresa';
    if (companyDetailsEl) {
      if (comp.name && comp.phone) {
        companyDetailsEl.textContent = `${comp.email || ''} | ${comp.phone || ''}`;
      } else {
        companyDetailsEl.textContent = 'Configura los datos de tu empresa en Ajustes';
      }
    }

    if (logoContainer) {
      if (comp.logoBase64) {
        logoContainer.innerHTML = `<img src="${formatLogoSrc(comp.logoBase64)}" alt="Company Logo">`;
      } else {
        logoContainer.innerHTML = `<i class="ri-building-4-line"></i>`;
      }
    }

    // Missing profile alert
    const missingAlert = document.getElementById('alert-missing-company');
    if (missingAlert) {
      missingAlert.style.display = (!comp.name || !comp.phone || !comp.email) ? 'flex' : 'none';
    }

    // Dashboard Statistics Calculation
    const totalCount = quotes.length;
    const acceptedQuotes = quotes.filter(q => q.status === 'Aceptado');
    const pendingQuotes = quotes.filter(q => q.status === 'Pendiente');
    const totalEarnings = acceptedQuotes.reduce((sum, q) => sum + (q.total || 0), 0);

    const totalEarningsEl = document.getElementById('dash-total-earnings');
    const acceptedCountEl = document.getElementById('dash-accepted-count');
    const statTotalEl = document.getElementById('dash-stat-total');
    const statPendingEl = document.getElementById('dash-stat-pending');

    if (totalEarningsEl) totalEarningsEl.textContent = formatCurrency(totalEarnings);
    if (acceptedCountEl) acceptedCountEl.textContent = `${acceptedQuotes.length} presupuestos aprobados`;
    if (statTotalEl) statTotalEl.textContent = totalCount;
    if (statPendingEl) statPendingEl.textContent = pendingQuotes.length;

    // Recent Quotes List (take 5)
    const recentQuotesList = document.getElementById('dash-recent-quotes-list');
    if (recentQuotesList) {
      const recent = [...quotes].sort((a, b) => new Date(b.date) - new Date(a.date)).slice(0, 5);
      if (recent.length === 0) {
        recentQuotesList.innerHTML = `
          <div class="card card-body text-center" style="padding: 32px;">
            <i class="ri-file-list-3-line" style="font-size: 48px; color: var(--color-accent);"></i>
            <h4 class="margin-top-md">Sin presupuestos todavía</h4>
            <p class="card-description">Crea tu primer presupuesto para comenzar.</p>
            <button class="btn btn-accent margin-top-md" id="btn-create-first-quote">
              <i class="ri-add-line"></i> Crear Presupuesto
            </button>
          </div>
        `;
        document.getElementById('btn-create-first-quote')?.addEventListener('click', openNewQuoteModal);
      } else {
        recentQuotesList.innerHTML = recent.map(q => renderQuoteCardItem(q)).join('');
        attachQuoteCardClickListeners(recentQuotesList);
      }
    }
  }

  function renderQuoteCardItem(quote) {
    return `
      <div class="quote-item-card" data-quote-id="${quote.id}">
        <div class="quote-card-left">
          <span class="status-dot ${quote.status}"></span>
          <div class="quote-card-info">
            <span class="quote-client-name">${escapeHtml(quote.clientName)}</span>
            <span class="quote-meta-sub">
              <span>#${quote.number} (${quote.status})</span>
              <span>•</span>
              <span>${getTimeElapsed(quote.date)}</span>
            </span>
          </div>
        </div>
        <div class="quote-card-right">
          <span class="quote-price">${formatCurrency(quote.total)}</span>
          <i class="ri-arrow-right-s-line" style="color: var(--text-muted); font-size: 18px;"></i>
        </div>
      </div>
    `;
  }

  function attachQuoteCardClickListeners(container) {
    container.querySelectorAll('.quote-item-card').forEach(card => {
      card.addEventListener('click', () => {
        const id = card.getAttribute('data-quote-id');
        openQuoteDetailsModal(id);
      });
    });
  }

  // 2. Render History View (Historial)
  function renderHistoryView() {
    const container = document.getElementById('history-quotes-list');
    if (!container) return;

    let filtered = [...appState.quotes];
    const { query, status } = appState.historyFilters;

    // Search query filter
    if (query) {
      const qLower = query.toLowerCase();
      filtered = filtered.filter(q =>
        q.clientName.toLowerCase().includes(qLower) ||
        q.number.includes(qLower)
      );
    }

    // Status filter
    if (status && status !== 'Todos') {
      filtered = filtered.filter(q => q.status === status);
    }

    // Sort newest first
    filtered.sort((a, b) => new Date(b.date) - new Date(a.date));

    if (filtered.length === 0) {
      container.innerHTML = `
        <div class="card card-body text-center" style="padding: 32px;">
          <i class="ri-file-search-line" style="font-size: 48px; color: var(--text-muted);"></i>
          <h4 class="margin-top-md">No se encontraron presupuestos</h4>
          <p class="card-description">Intenta modificar tus filtros de búsqueda.</p>
        </div>
      `;
    } else {
      container.innerHTML = filtered.map(q => renderQuoteCardItem(q)).join('');
      attachQuoteCardClickListeners(container);
    }
  }

  // 3. Render Services View (Servicios)
  function renderServicesView() {
    const container = document.getElementById('services-grouped-container');
    if (!container) return;

    const query = appState.servicesSearchQuery.toLowerCase();
    const filtered = appState.services.filter(s =>
      s.name.toLowerCase().includes(query) ||
      (s.category && s.category.toLowerCase().includes(query))
    );

    // Group by category
    const grouped = {};
    filtered.forEach(srv => {
      const cat = srv.category || 'Sin categoría';
      if (!grouped[cat]) grouped[cat] = [];
      grouped[cat].push(srv);
    });

    const categoryKeys = Object.keys(grouped).sort((a, b) => {
      if (a === 'Sin categoría') return -1;
      if (b === 'Sin categoría') return 1;
      return a.localeCompare(b);
    });

    if (categoryKeys.length === 0) {
      container.innerHTML = `
        <div class="card card-body text-center" style="padding: 32px;">
          <i class="ri-tools-line" style="font-size: 48px; color: var(--text-muted);"></i>
          <h4 class="margin-top-md">${query ? 'No se encontraron servicios' : 'Aún no has guardado servicios frecuentes'}</h4>
          <p class="card-description">Agrega servicios por categoría para autocompletar tus presupuestos.</p>
          <button class="btn btn-accent margin-top-md" id="btn-create-first-service">
            <i class="ri-add-line"></i> Agregar Servicio
          </button>
        </div>
      `;
      document.getElementById('btn-create-first-service')?.addEventListener('click', () => openServiceFormModal());
    } else {
      container.innerHTML = categoryKeys.map(cat => {
        const items = grouped[cat];
        return `
          <div class="accordion-item expanded">
            <div class="accordion-header">
              <div class="accordion-header-left">
                <i class="ri-folder-line"></i>
                <h4>${escapeHtml(cat)}</h4>
                <span class="accordion-count">(${items.length})</span>
              </div>
              <i class="ri-arrow-down-s-line accordion-chevron"></i>
            </div>
            <div class="accordion-content">
              ${items.map(srv => `
                <div class="service-row">
                  <div>
                    <div class="service-name">${escapeHtml(srv.name)}</div>
                    <div class="service-category-tag">${escapeHtml(srv.category)}</div>
                  </div>
                  <div style="display:flex; align-items:center; gap: 12px;">
                    <span class="service-price">${formatCurrency(srv.price)}</span>
                    <button class="btn-text btn-edit-srv" data-id="${srv.id}" title="Editar"><i class="ri-edit-line"></i></button>
                    <button class="btn-text btn-text-danger btn-del-srv" data-id="${srv.id}" title="Eliminar"><i class="ri-delete-bin-line"></i></button>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>
        `;
      }).join('');

      // Attach accordion toggle listeners
      container.querySelectorAll('.accordion-header').forEach(hdr => {
        hdr.addEventListener('click', () => {
          const item = hdr.parentElement;
          item.classList.toggle('expanded');
        });
      });

      // Attach Edit/Delete service listeners
      container.querySelectorAll('.btn-edit-srv').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const id = btn.getAttribute('data-id');
          openServiceFormModal(id);
        });
      });

      container.querySelectorAll('.btn-del-srv').forEach(btn => {
        btn.addEventListener('click', (e) => {
          e.stopPropagation();
          const id = btn.getAttribute('data-id');
          deleteService(id);
        });
      });
    }
  }

  // 4. Render Settings View (Configuración)
  function renderSettingsView() {
    const comp = appState.company;

    const nameInput = document.getElementById('company-name');
    const addrInput = document.getElementById('company-address');
    const phoneInput = document.getElementById('company-phone');
    const emailInput = document.getElementById('company-email');
    const webInput = document.getElementById('company-website');

    if (nameInput) nameInput.value = comp.name || '';
    if (addrInput) addrInput.value = comp.address || '';
    if (phoneInput) phoneInput.value = comp.phone || '';
    if (emailInput) emailInput.value = comp.email || '';
    if (webInput) webInput.value = comp.website || '';

    // Logo Avatar render
    const logoImg = document.getElementById('logo-img-element');
    const logoIcon = document.getElementById('logo-placeholder-icon');
    const removeBtn = document.getElementById('btn-remove-logo');

    if (comp.logoBase64) {
      if (logoImg) { logoImg.src = formatLogoSrc(comp.logoBase64); logoImg.style.display = 'block'; }
      if (logoIcon) logoIcon.style.display = 'none';
      if (removeBtn) removeBtn.style.display = 'inline-flex';
    } else {
      if (logoImg) logoImg.style.display = 'none';
      if (logoIcon) logoIcon.style.display = 'block';
      if (removeBtn) removeBtn.style.display = 'none';
    }
  }

  /* ==========================================================================
     QUOTES LOGIC (NEW QUOTE & DETAILS)
     ========================================================================== */
  function getNextQuoteNumber() {
    if (appState.quotes.length === 0) return '0001';
    let max = 0;
    appState.quotes.forEach(q => {
      const num = parseInt(q.number, 10);
      if (!isNaN(num) && num > max) max = num;
    });
    return String(max + 1).padStart(4, '0');
  }

  function openNewQuoteModal() {
    appState.currentQuoteItems = [];
    appState.editingQuoteId = null;

    document.getElementById('nq-number').textContent = getNextQuoteNumber();
    document.getElementById('nq-date').textContent = formatDate(new Date().toISOString());

    // Reset Form fields
    document.getElementById('form-new-quote').reset();
    document.getElementById('nq-service-category').value = 'Todas';

    populateServiceCategoriesDropdown();
    renderNewQuoteItemsList();

    showModal('modal-new-quote');
  }

  function populateServiceCategoriesDropdown() {
    const select = document.getElementById('nq-service-category');
    if (!select) return;

    const categories = Array.from(new Set(appState.services.map(s => s.category || 'Sin categoría')));
    select.innerHTML = `<option value="Todas">Todas</option>` +
      categories.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('');
  }

  function renderNewQuoteItemsList() {
    const container = document.getElementById('nq-items-container');
    const emptyState = document.getElementById('nq-empty-items');
    const totalsBox = document.getElementById('nq-totals-box');

    if (appState.currentQuoteItems.length === 0) {
      if (emptyState) emptyState.style.display = 'block';
      if (totalsBox) totalsBox.style.display = 'none';
      if (container) container.innerHTML = emptyState.outerHTML;
      return;
    }

    if (emptyState) emptyState.style.display = 'none';
    if (totalsBox) totalsBox.style.display = 'flex';

    container.innerHTML = appState.currentQuoteItems.map((item, index) => `
      <div class="service-row" style="padding: 10px 0;">
        <div>
          <div style="font-weight: 700;">${escapeHtml(item.name)}</div>
          <div style="font-size: 12px; color: var(--text-secondary);">
            Cantidad: ${item.quantity} • ${formatCurrency(item.price)} c/u
          </div>
        </div>
        <div style="display:flex; align-items:center; gap: 10px;">
          <span style="font-weight:800; font-size:14px; color:var(--color-accent);">
            ${formatCurrency(item.price * item.quantity)}
          </span>
          <button type="button" class="btn-text btn-text-danger btn-remove-nq-item" data-index="${index}">
            <i class="ri-delete-bin-line"></i>
          </button>
        </div>
      </div>
    `).join('');

    container.querySelectorAll('.btn-remove-nq-item').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.getAttribute('data-index'));
        appState.currentQuoteItems.splice(idx, 1);
        renderNewQuoteItemsList();
        calculateNewQuoteTotals();
      });
    });

    calculateNewQuoteTotals();
  }

  function calculateNewQuoteTotals() {
    const subtotal = appState.currentQuoteItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const pctInput = document.getElementById('nq-discount-pct');
    const reasonInput = document.getElementById('nq-discount-reason');

    let discountPct = parseFloat(pctInput.value) || 0;
    if (discountPct < 0) discountPct = 0;
    if (discountPct > 100) discountPct = 100;

    const discountAmount = subtotal * (discountPct / 100);
    const total = Math.max(0, subtotal - discountAmount);

    const subtotalRow = document.getElementById('nq-subtotal-row');
    const discountRow = document.getElementById('nq-discount-row');
    const discountLabel = document.getElementById('nq-discount-label');

    if (discountPct > 0) {
      if (subtotalRow) subtotalRow.style.display = 'flex';
      if (discountRow) discountRow.style.display = 'flex';
      document.getElementById('nq-subtotal-val').textContent = formatCurrency(subtotal);
      
      const reason = reasonInput.value.trim();
      discountLabel.textContent = reason ? `Descuento (${reason} - ${discountPct}%)` : `Descuento (${discountPct}%)`;
      document.getElementById('nq-discount-val').textContent = `-${formatCurrency(discountAmount)}`;
    } else {
      if (subtotalRow) subtotalRow.style.display = 'none';
      if (discountRow) discountRow.style.display = 'none';
    }

    document.getElementById('nq-total-val').textContent = formatCurrency(total);
  }

  function addServiceItemToQuote() {
    const nameInput = document.getElementById('nq-service-name');
    const priceInput = document.getElementById('nq-service-price');
    const qtyInput = document.getElementById('nq-service-qty');

    const name = nameInput.value.trim();
    const price = parseFloat(priceInput.value) || 0;
    const quantity = parseInt(qtyInput.value) || 1;

    if (!name) {
      showToast('Ingresa el nombre del servicio');
      return;
    }
    if (price <= 0) {
      showToast('Ingresa un precio válido mayor a 0');
      return;
    }

    appState.currentQuoteItems.push({ name, price, quantity });

    // Reset inputs
    nameInput.value = '';
    priceInput.value = '';
    qtyInput.value = '1';

    renderNewQuoteItemsList();
    showToast('Servicio añadido al presupuesto');
  }

  function saveQuote(generatePdfAfter = false) {
    const clientName = document.getElementById('nq-client-name').value.trim();
    const clientPhone = document.getElementById('nq-client-phone').value.trim();
    const clientAddress = document.getElementById('nq-client-address').value.trim();
    const observations = document.getElementById('nq-observations').value.trim();
    const discountReason = document.getElementById('nq-discount-reason').value.trim();
    const discountPct = parseFloat(document.getElementById('nq-discount-pct').value) || 0;

    if (!clientName) {
      showToast('Ingresa el nombre del cliente');
      return;
    }

    if (appState.currentQuoteItems.length === 0) {
      showToast('Por favor, agrega al menos un servicio al presupuesto');
      return;
    }

    const subtotal = appState.currentQuoteItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const discountAmount = subtotal * (discountPct / 100);
    const total = Math.max(0, subtotal - discountAmount);

    const newQuote = {
      id: Date.now().toString(),
      number: getNextQuoteNumber(),
      date: new Date().toISOString(),
      clientName,
      clientPhone,
      clientAddress,
      items: [...appState.currentQuoteItems],
      total,
      status: 'Pendiente',
      observations,
      discountReason,
      discountPercentage: discountPct
    };

    appState.quotes.unshift(newQuote);
    saveQuotesToStorage();
    syncQuoteToCloud(newQuote);
    renderAllViews();
    hideModal('modal-new-quote');

    showToast(`Presupuesto N° ${newQuote.number} guardado con éxito.`);

    if (generatePdfAfter) {
      generateQuotePDF(newQuote);
    }
  }

  // Quote Details Modal
  function openQuoteDetailsModal(quoteId) {
    const quote = appState.quotes.find(q => q.id === quoteId);
    if (!quote) return;

    appState.editingQuoteId = quoteId;

    document.getElementById('qd-title').textContent = `Presupuesto #${quote.number}`;
    document.getElementById('qd-status-select').value = quote.status;
    document.getElementById('qd-client-name').textContent = quote.clientName;
    document.getElementById('qd-client-phone').textContent = quote.clientPhone || 'N/A';
    document.getElementById('qd-client-address').textContent = quote.clientAddress || 'N/A';
    document.getElementById('qd-date').textContent = formatDate(quote.date);

    // Items table
    const tbody = document.getElementById('qd-items-body');
    tbody.innerHTML = quote.items.map(item => `
      <tr>
        <td>${item.quantity}x</td>
        <td>
          <div>${escapeHtml(item.name)}</div>
          <div style="font-size: 11px; color: var(--text-muted);">${formatCurrency(item.price)} c/u</div>
        </td>
        <td class="text-right">${formatCurrency(item.price * item.quantity)}</td>
      </tr>
    `).join('');

    // Totals
    const subtotal = quote.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const discountRow = document.getElementById('qd-discount-row');
    const subtotalRow = document.getElementById('qd-subtotal-row');

    if (quote.discountPercentage > 0) {
      const discountAmount = subtotal * (quote.discountPercentage / 100);
      subtotalRow.style.display = 'block';
      discountRow.style.display = 'block';
      document.getElementById('qd-subtotal-val').textContent = formatCurrency(subtotal);
      document.getElementById('qd-discount-label').textContent = quote.discountReason
        ? `Descuento (${quote.discountReason} - ${quote.discountPercentage}%):`
        : `Descuento (${quote.discountPercentage}%):`;
      document.getElementById('qd-discount-val').textContent = `-${formatCurrency(discountAmount)}`;
    } else {
      subtotalRow.style.display = 'none';
      discountRow.style.display = 'none';
    }

    document.getElementById('qd-total-val').textContent = formatCurrency(quote.total);

    // Observations
    const obsSection = document.getElementById('qd-obs-section');
    const obsText = document.getElementById('qd-observations');
    if (quote.observations) {
      obsSection.style.display = 'block';
      obsText.textContent = quote.observations;
    } else {
      obsSection.style.display = 'none';
    }

    showModal('modal-quote-details');
  }

  function updateQuoteStatus(newStatus) {
    if (!appState.editingQuoteId) return;
    const quote = appState.quotes.find(q => q.id === appState.editingQuoteId);
    if (quote) {
      quote.status = newStatus;
      saveQuotesToStorage();
      syncQuoteToCloud(quote);
      renderAllViews();
      showToast(`Estado actualizado a ${newStatus}`);
    }
  }

  function deleteCurrentQuote() {
    if (!appState.editingQuoteId) return;
    if (confirm('¿Estás seguro de que deseas eliminar este presupuesto? Esta acción no se puede deshacer.')) {
      const idToDelete = appState.editingQuoteId;
      appState.quotes = appState.quotes.filter(q => q.id !== idToDelete);
      saveQuotesToStorage();
      deleteQuoteFromCloud(idToDelete);
      renderAllViews();
      hideModal('modal-quote-details');
      showToast('Presupuesto eliminado');
    }
  }

  /* ==========================================================================
     SERVICE CATALOG & EXCEL IMPORT/EXPORT
     ========================================================================== */
  function openServiceFormModal(serviceId = null) {
    const form = document.getElementById('form-service');
    form.reset();

    const titleEl = document.getElementById('sf-title');
    const idInput = document.getElementById('sf-id');
    const categorySelect = document.getElementById('sf-category-select');

    // Populate categories
    const categories = Array.from(new Set(['Sin categoría', ...appState.services.map(s => s.category || 'Sin categoría')]));
    categorySelect.innerHTML = categories.map(c => `<option value="${escapeHtml(c)}">${escapeHtml(c)}</option>`).join('');

    if (serviceId) {
      const srv = appState.services.find(s => s.id === serviceId);
      if (srv) {
        titleEl.textContent = 'Editar Servicio';
        idInput.value = srv.id;
        document.getElementById('sf-name').value = srv.name;
        document.getElementById('sf-price').value = srv.price;
        categorySelect.value = srv.category || 'Sin categoría';
      }
    } else {
      titleEl.textContent = 'Nuevo Servicio Frecuente';
      idInput.value = '';
    }

    showModal('modal-service-form');
  }

  function saveService(e) {
    e.preventDefault();
    const id = document.getElementById('sf-id').value;
    const name = document.getElementById('sf-name').value.trim();
    const price = parseFloat(document.getElementById('sf-price').value) || 0;
    const category = document.getElementById('sf-category-select').value || 'Sin categoría';

    if (!name || price <= 0) {
      showToast('Ingresa un nombre y precio válido');
      return;
    }

    let targetService = null;
    if (id) {
      // Edit existing
      targetService = appState.services.find(s => s.id === id);
      if (targetService) {
        targetService.name = name;
        targetService.price = price;
        targetService.category = category;
      }
    } else {
      // Add new
      targetService = {
        id: Date.now().toString(),
        name,
        price,
        category
      };
      appState.services.push(targetService);
    }

    saveServicesToStorage();
    if (targetService) syncServiceToCloud(targetService);
    renderAllViews();
    hideModal('modal-service-form');
    showToast(id ? 'Servicio actualizado' : 'Servicio guardado');
  }

  function deleteService(id) {
    if (confirm('¿Estás seguro de que deseas eliminar este servicio de tu base?')) {
      appState.services = appState.services.filter(s => s.id !== id);
      saveServicesToStorage();
      deleteServiceFromCloud(id);
      renderAllViews();
      showToast('Servicio eliminado');
    }
  }

  function downloadServicesExcelTemplate() {
    if (typeof XLSX === 'undefined') {
      showToast('Librería de Excel no cargada');
      return;
    }

    const data = appState.services.map(s => ({
      Categoría: s.category || 'Sin categoría',
      Servicio: s.name,
      'Precio Sugerido': s.price
    }));

    const ws = XLSX.utils.json_to_sheet(data);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, 'Servicios');

    XLSX.writeFile(wb, 'base_servicios_budapp.xlsx');
    showToast('Archivo Excel descargado');
  }

  function importServicesFromExcel(file) {
    if (typeof XLSX === 'undefined') {
      showToast('Librería de Excel no cargada');
      return;
    }

    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = new Uint8Array(e.target.result);
        const workbook = XLSX.read(data, { type: 'array' });
        const firstSheet = workbook.SheetNames[0];
        const rows = XLSX.utils.sheet_to_json(workbook.Sheets[firstSheet]);

        let count = 0;
        rows.forEach(row => {
          const name = row['Servicio'] || row['servicio'] || row['Nombre'] || row['name'];
          const price = parseFloat(row['Precio Sugerido'] || row['Precio'] || row['price']) || 0;
          const category = row['Categoría'] || row['categoria'] || row['category'] || 'Sin categoría';

          if (name && price > 0) {
            // Overwrite existing or add new
            const existing = appState.services.find(s => s.name.toLowerCase() === name.toLowerCase());
            if (existing) {
              existing.price = price;
              existing.category = category;
            } else {
              appState.services.push({
                id: Date.now().toString() + '_' + count,
                name,
                price,
                category
              });
            }
            count++;
          }
        });

        saveServicesToStorage();
        renderAllViews();
        showToast(`Se importaron ${count} servicios correctamente.`);
      } catch (err) {
        showToast('Error al leer archivo Excel');
      }
    };
    reader.readAsArrayBuffer(file);
  }

  /* ==========================================================================
     PDF GENERATION & PRINT ENGINE
     Direct layout replica of Flutter PdfGenerator
     ========================================================================== */
  function generateQuotePDF(quoteToPrint = null) {
    const quote = quoteToPrint || appState.quotes.find(q => q.id === appState.editingQuoteId);
    if (!quote) return;

    const company = appState.company;
    const subtotal = quote.items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
    const discountAmount = subtotal * ((quote.discountPercentage || 0) / 100);

    const pdfHtml = `
      <div style="font-family: 'Inter', sans-serif; padding: 40px; color: #1E293B; background: #FFF; width: 800px; margin: auto;">
        <!-- Header -->
        <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #0D9488; padding-bottom: 16px;">
          <div style="display: flex; gap: 16px; align-items: flex-start;">
            ${company.logoBase64 ? `<img src="${formatLogoSrc(company.logoBase64)}" style="width: 70px; height: 70px; object-fit: contain; border-radius: 8px;">` : ''}
            <div>
              <h2 style="color: #0F766E; font-size: 20px; margin: 0 0 4px 0;">${escapeHtml(company.name || 'Servicios Técnicos')}</h2>
              ${company.address ? `<div style="font-size: 11px; color: #475569;">${escapeHtml(company.address)}</div>` : ''}
              ${company.phone ? `<div style="font-size: 11px; color: #475569;">Tel: ${escapeHtml(company.phone)}</div>` : ''}
              ${company.email ? `<div style="font-size: 11px; color: #475569;">Email: ${escapeHtml(company.email)}</div>` : ''}
              ${company.website ? `<div style="font-size: 11px; color: #475569;">Web: ${escapeHtml(company.website)}</div>` : ''}
            </div>
          </div>
          <div style="text-align: right;">
            <h1 style="color: #0D9488; font-size: 24px; margin: 0; font-weight: 800;">PRESUPUESTO</h1>
            <div style="font-size: 14px; font-weight: 700; margin-top: 6px;">N°: ${quote.number}</div>
            <div style="font-size: 11px; color: #64748B;">Fecha: ${formatDate(quote.date)}</div>
          </div>
        </div>

        <!-- Client Block -->
        <div style="background-color: #F1F5F9; border-radius: 8px; padding: 14px; margin-top: 20px;">
          <div style="font-size: 11px; font-weight: 800; color: #0F766E; letter-spacing: 0.5px; margin-bottom: 6px;">CLIENTE</div>
          <div style="font-size: 12px; margin-bottom: 3px;"><strong>Nombre:</strong> ${escapeHtml(quote.clientName)}</div>
          ${quote.clientPhone ? `<div style="font-size: 12px; margin-bottom: 3px;"><strong>Teléfono:</strong> ${escapeHtml(quote.clientPhone)}</div>` : ''}
          ${quote.clientAddress ? `<div style="font-size: 12px;"><strong>Dirección:</strong> ${escapeHtml(quote.clientAddress)}</div>` : ''}
        </div>

        <!-- Items Table -->
        <div style="margin-top: 24px;">
          <div style="font-size: 11px; font-weight: 800; color: #0F766E; letter-spacing: 0.5px; margin-bottom: 8px;">DETALLE DE CONCEPTOS / SERVICIOS</div>
          <table style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="background-color: #0D9488; color: #FFF; font-size: 11px;">
                <th style="padding: 8px; text-align: center; width: 60px;">Cant.</th>
                <th style="padding: 8px; text-align: left;">Servicio</th>
                <th style="padding: 8px; text-align: right; width: 120px;">Precio Unit.</th>
                <th style="padding: 8px; text-align: right; width: 120px;">Subtotal</th>
              </tr>
            </thead>
            <tbody>
              ${quote.items.map(item => `
                <tr style="border-bottom: 1px solid #E2E8F0; font-size: 11px;">
                  <td style="padding: 8px; text-align: center;">${item.quantity}</td>
                  <td style="padding: 8px;">${escapeHtml(item.name)}</td>
                  <td style="padding: 8px; text-align: right;">${formatCurrency(item.price)}</td>
                  <td style="padding: 8px; text-align: right;">${formatCurrency(item.price * item.quantity)}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>

        <!-- Totals Summary -->
        <div style="display: flex; justify-content: flex-end; margin-top: 16px;">
          <div style="background-color: #CCFBF1; padding: 12px 18px; border-radius: 8px; text-align: right; min-width: 240px;">
            ${quote.discountPercentage > 0 ? `
              <div style="font-size: 11px; color: #475569;">Subtotal: ${formatCurrency(subtotal)}</div>
              <div style="font-size: 11px; color: #DC2626; margin: 4px 0;">
                Descuento (${quote.discountReason || ''} - ${quote.discountPercentage}%): -${formatCurrency(discountAmount)}
              </div>
              <div style="border-top: 1px solid #99F6E4; margin: 6px 0;"></div>
            ` : ''}
            <div style="font-size: 16px; font-weight: 800; color: #0F766E;">
              TOTAL: ${formatCurrency(quote.total)}
            </div>
          </div>
        </div>

        <!-- Observations -->
        ${quote.observations ? `
          <div style="margin-top: 24px; border: 1px solid #CBD5E1; border-radius: 8px; padding: 12px;">
            <div style="font-size: 11px; font-weight: 800; color: #475569; margin-bottom: 4px;">Observaciones:</div>
            <div style="font-size: 11px; color: #334155;">${escapeHtml(quote.observations)}</div>
          </div>
        ` : ''}

        <!-- Footer clause -->
        <div style="margin-top: 40px; text-align: center; font-size: 10px; color: #94A3B8;">
          Este presupuesto tiene validez por 15 días a partir de la fecha de emisión.
          <br>
          <strong style="color: #0F766E;">¡Gracias por confiar en nosotros!</strong>
        </div>
      </div>
    `;

    if (typeof html2pdf !== 'undefined') {
      const opt = {
        margin: 0,
        filename: `presupuesto_${quote.number}.pdf`,
        image: { type: 'jpeg', quality: 0.98 },
        html2canvas: { scale: 2 },
        jsPDF: { unit: 'in', format: 'a4', orientation: 'portrait' }
      };

      const element = document.createElement('div');
      element.innerHTML = pdfHtml;
      html2pdf().set(opt).from(element).save();
      showToast(`Descargando PDF Presupuesto N° ${quote.number}`);
    } else {
      // Fallback to Window Print
      const printWin = window.open('', '_blank');
      printWin.document.write(`<html><head><title>Presupuesto #${quote.number}</title></head><body>${pdfHtml}</body></html>`);
      printWin.document.close();
      printWin.focus();
      setTimeout(() => printWin.print(), 500);
    }
  }

  function shareQuoteWhatsApp() {
    const quote = appState.quotes.find(q => q.id === appState.editingQuoteId);
    if (!quote) return;

    const itemsSummary = quote.items.map(i => `• ${i.quantity}x ${i.name} (${formatCurrency(i.price * i.quantity)})`).join('\n');
    const msg = `*Presupuesto N° ${quote.number}*\n` +
      `Cliente: ${quote.clientName}\n\n` +
      `*Detalle:*\n${itemsSummary}\n\n` +
      `*Total:* ${formatCurrency(quote.total)}\n` +
      `${quote.observations ? `Observaciones: ${quote.observations}\n` : ''}` +
      `\n¡Gracias por su consulta!`;

    const encoded = encodeURIComponent(msg);
    window.open(`https://wa.me/?text=${encoded}`, '_blank');
  }

  /* ==========================================================================
     JSON BACKUP EXPORT & IMPORT
     ========================================================================== */
  function exportJSONBackup() {
    const backupData = {
      version: '1.0.0',
      exportDate: new Date().toISOString(),
      company: appState.company,
      quotes: appState.quotes,
      services: appState.services,
      theme: appState.theme
    };

    const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `budapp_backup_${new Date().toISOString().slice(0,10)}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('Copia de seguridad JSON descargada');
  }

  function importJSONBackup(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const data = JSON.parse(e.target.result);
        if (data.company) appState.company = data.company;
        if (data.quotes) appState.quotes = data.quotes;
        if (data.services) appState.services = data.services;
        if (data.theme) appState.theme = data.theme;

        saveCompanyToStorage();
        saveQuotesToStorage();
        saveServicesToStorage();
        saveThemeToStorage();

        setupTheme();
        renderAllViews();
        showToast('Copia de seguridad restaurada con éxito.');
      } catch (err) {
        showToast('Error al importar copia JSON. Archivo no válido.');
      }
    };
    reader.readAsText(file);
  }

  /* ==========================================================================
     MODAL DIALOG HELPERS & TOASTS
     ========================================================================== */
  function showModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.style.display = 'flex';
  }

  function hideModal(modalId) {
    const modal = document.getElementById(modalId);
    if (modal) modal.style.display = 'none';
  }

  function showToast(message) {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    container.appendChild(toast);

    setTimeout(() => {
      toast.remove();
    }, 3000);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  /* ==========================================================================
     EVENT LISTENERS & BINDINGS
     ========================================================================== */
  function setupEventListeners() {
    // 0. Welcome & Authentication Handlers
    document.getElementById('btn-welcome-auth')?.addEventListener('click', () => {
      document.getElementById('welcome-options-box').style.display = 'none';
      document.getElementById('welcome-auth-box').style.display = 'block';
    });

    document.getElementById('btn-back-to-welcome-options')?.addEventListener('click', () => {
      document.getElementById('welcome-options-box').style.display = 'flex';
      document.getElementById('welcome-auth-box').style.display = 'none';
    });

    document.getElementById('btn-welcome-guest')?.addEventListener('click', () => {
      appState.auth = {
        isAuthenticated: false,
        userEmail: '',
        isGuest: true
      };
      saveAuthToStorage();
      checkSessionState();
      showToast('Entrando en modo Invitado (Almacenamiento Local)');
    });

    document.getElementById('btn-welcome-test-firebase')?.addEventListener('click', async () => {
      if (!db) {
        showToast('Firebase no está disponible');
        return;
      }
      showToast('Probando conexión con Firebase...');
      try {
        const testDocRef = db.collection('connection_tests').doc('test_connection');
        await testDocRef.set({
          timestamp: firebase.firestore.FieldValue.serverTimestamp(),
          status: 'checking_reachability'
        });
        alert('¡Conexión Exitosa!\nFirebase está completamente operativo. Se logró escribir y leer en Cloud Firestore.');
      } catch (e) {
        if (e.message && e.message.includes('permission-denied')) {
          alert('¡Conexión Exitosa (Segura)!\nLa base de datos Firebase es accesible y responde. (Bloqueada por reglas de seguridad de Firestore, lo cual es normal sin iniciar sesión).');
        } else {
          alert('Error de Conexión a Firebase:\n' + e.message);
        }
      }
    });

    // Toggle Auth Form mode (Login / Sign Up)
    document.getElementById('btn-toggle-auth-mode')?.addEventListener('click', () => {
      appState.isSignUpMode = !appState.isSignUpMode;
      const title = document.getElementById('auth-title');
      const subtitle = document.getElementById('auth-subtitle-text');
      const submitBtn = document.getElementById('btn-submit-auth');
      const toggleBtn = document.getElementById('btn-toggle-auth-mode');

      if (appState.isSignUpMode) {
        if (title) title.textContent = 'Crear Cuenta';
        if (subtitle) subtitle.textContent = 'Únete a Budapp para guardar tus presupuestos en la nube.';
        if (submitBtn) submitBtn.innerHTML = `<i class="ri-user-add-line"></i> Registrarse y Entrar`;
        if (toggleBtn) toggleBtn.textContent = '¿Ya tienes una cuenta? Inicia sesión aquí';
      } else {
        if (title) title.textContent = 'Iniciar Sesión';
        if (subtitle) subtitle.textContent = 'Accede a tu cuenta para sincronizar tus presupuestos en la nube.';
        if (submitBtn) submitBtn.innerHTML = `<i class="ri-login-circle-line"></i> Iniciar Sesión`;
        if (toggleBtn) toggleBtn.textContent = '¿No tienes cuenta? Regístrate aquí';
      }
    });

    // Submit Auth Form via Firebase Auth
    document.getElementById('form-welcome-auth')?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('auth-email-input').value.trim();
      const password = document.getElementById('auth-password-input').value.trim();

      if (!email || !password) {
        showToast('Completa el correo y la contraseña');
        return;
      }

      if (!auth) {
        showToast('Servicio de Firebase no configurado en la web.');
        return;
      }

      const submitBtn = document.getElementById('btn-submit-auth');
      const originalText = submitBtn ? submitBtn.innerHTML : '';
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.innerHTML = '<i class="ri-loader-4-line spin"></i> Conectando...';
      }

      try {
        if (appState.isSignUpMode) {
          await auth.createUserWithEmailAndPassword(email, password);
          showToast('Cuenta creada con éxito');
        } else {
          await auth.signInWithEmailAndPassword(email, password);
          showToast('Sesión iniciada con éxito');
        }
        showModal('modal-post-auth-sync');
      } catch (err) {
        let msg = err.message;
        if (err.code === 'auth/invalid-email') msg = 'El correo electrónico no es válido.';
        if (err.code === 'auth/user-not-found') msg = 'No se encontró ningún usuario con este correo electrónico.';
        if (err.code === 'auth/wrong-password' || err.code === 'auth/invalid-credential') msg = 'Contraseña o correo incorrecto.';
        if (err.code === 'auth/email-already-in-use') msg = 'Este correo electrónico ya está registrado.';
        if (err.code === 'auth/weak-password') msg = 'La contraseña debe tener al menos 6 caracteres.';
        showToast(msg);
      } finally {
        if (submitBtn) {
          submitBtn.disabled = false;
          submitBtn.innerHTML = originalText;
        }
      }
    });

    // Post Auth Sync Modal Options
    document.getElementById('btn-sync-upload')?.addEventListener('click', async () => {
      hideModal('modal-post-auth-sync');
      await uploadToCloud(true);
      checkSessionState();
    });

    document.getElementById('btn-sync-download')?.addEventListener('click', async () => {
      hideModal('modal-post-auth-sync');
      await syncFromCloud(true);
      checkSessionState();
    });

    document.getElementById('btn-sync-ignore')?.addEventListener('click', () => {
      hideModal('modal-post-auth-sync');
      checkSessionState();
      showToast('Sesión iniciada en Budapp');
    });

    // Top Bar & Settings Logout
    document.getElementById('btn-top-logout')?.addEventListener('click', logoutUser);
    document.getElementById('btn-settings-logout')?.addEventListener('click', logoutUser);

    // 1. Navigation Tabs
    document.querySelectorAll('[data-tab]').forEach(el => {
      el.addEventListener('click', () => {
        const tab = el.getAttribute('data-tab');
        switchTab(tab);
      });
    });

    // Quick Actions
    document.getElementById('qa-new')?.addEventListener('click', openNewQuoteModal);
    document.getElementById('qa-history')?.addEventListener('click', () => switchTab('history'));
    document.getElementById('qa-services')?.addEventListener('click', () => switchTab('services'));
    document.getElementById('qa-settings')?.addEventListener('click', () => switchTab('settings'));
    document.getElementById('sidebar-btn-new-quote')?.addEventListener('click', openNewQuoteModal);
    document.getElementById('dash-btn-new-quote')?.addEventListener('click', openNewQuoteModal);
    document.getElementById('fab-new-quote')?.addEventListener('click', openNewQuoteModal);
    document.getElementById('btn-fix-company')?.addEventListener('click', () => switchTab('settings'));

    // Dark Theme Toggle
    document.getElementById('btn-toggle-dark')?.addEventListener('click', () => {
      appState.theme.isDark = !appState.theme.isDark;
      saveThemeToStorage();
      setupTheme();
    });

    // Company Settings Form
    document.getElementById('form-company-settings')?.addEventListener('submit', (e) => {
      e.preventDefault();
      appState.company.name = document.getElementById('company-name').value.trim();
      appState.company.address = document.getElementById('company-address').value.trim();
      appState.company.phone = document.getElementById('company-phone').value.trim();
      appState.company.email = document.getElementById('company-email').value.trim();
      appState.company.website = document.getElementById('company-website').value.trim();

      saveCompanyToStorage();
      renderAllViews();
      showToast('Perfil de empresa guardado correctamente.');
    });

    // Logo Upload & Remove
    document.getElementById('logo-file-input')?.addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (file) {
        const reader = new FileReader();
        reader.onload = (evt) => {
          appState.company.logoBase64 = evt.target.result;
          saveCompanyToStorage();
          renderSettingsView();
          renderHomeView();
          showToast('Logo actualizado');
        };
        reader.readAsDataURL(file);
      }
    });

    document.getElementById('btn-remove-logo')?.addEventListener('click', () => {
      appState.company.logoBase64 = null;
      saveCompanyToStorage();
      renderSettingsView();
      renderHomeView();
      showToast('Logo eliminado');
    });

    // History Filters
    document.getElementById('hist-search-input')?.addEventListener('input', (e) => {
      appState.historyFilters.query = e.target.value;
      renderHistoryView();
    });

    document.getElementById('hist-status-filter')?.addEventListener('change', (e) => {
      appState.historyFilters.status = e.target.value;
      renderHistoryView();
    });

    // Services Search
    document.getElementById('srv-search-input')?.addEventListener('input', (e) => {
      appState.servicesSearchQuery = e.target.value;
      renderServicesView();
    });

    // Excel Import & Export
    document.getElementById('btn-download-services-template')?.addEventListener('click', downloadServicesExcelTemplate);
    document.getElementById('btn-import-services-excel')?.addEventListener('click', () => {
      document.getElementById('excel-file-input')?.click();
    });
    document.getElementById('excel-file-input')?.addEventListener('change', (e) => {
      if (e.target.files[0]) importServicesFromExcel(e.target.files[0]);
    });

    // JSON Backup Import & Export
    document.getElementById('btn-export-json')?.addEventListener('click', exportJSONBackup);
    document.getElementById('btn-import-json')?.addEventListener('click', () => {
      document.getElementById('json-file-input')?.click();
    });
    document.getElementById('json-file-input')?.addEventListener('change', (e) => {
      if (e.target.files[0]) importJSONBackup(e.target.files[0]);
    });

    // Modals Close handlers
    document.getElementById('close-modal-quote')?.addEventListener('click', () => hideModal('modal-new-quote'));
    document.getElementById('close-modal-details')?.addEventListener('click', () => hideModal('modal-quote-details'));
    document.getElementById('close-modal-service')?.addEventListener('click', () => hideModal('modal-service-form'));
    document.getElementById('close-modal-category')?.addEventListener('click', () => hideModal('modal-category-form'));
    document.getElementById('sf-btn-cancel')?.addEventListener('click', () => hideModal('modal-service-form'));
    document.getElementById('cat-btn-cancel')?.addEventListener('click', () => hideModal('modal-category-form'));

    // New Quote Handlers
    document.getElementById('nq-btn-add-item')?.addEventListener('click', addServiceItemToQuote);
    document.getElementById('nq-discount-pct')?.addEventListener('input', calculateNewQuoteTotals);
    document.getElementById('nq-discount-reason')?.addEventListener('input', calculateNewQuoteTotals);

    document.getElementById('nq-btn-save-only')?.addEventListener('click', () => saveQuote(false));
    document.getElementById('form-new-quote')?.addEventListener('submit', (e) => {
      e.preventDefault();
      saveQuote(true);
    });

    // Autocomplete Service Selector in New Quote Modal
    const srvNameInput = document.getElementById('nq-service-name');
    const autoList = document.getElementById('nq-autocomplete-list');

    if (srvNameInput && autoList) {
      srvNameInput.addEventListener('input', (e) => {
        const val = e.target.value.toLowerCase();
        const selectedCat = document.getElementById('nq-service-category').value;

        if (!val) {
          autoList.style.display = 'none';
          return;
        }

        const matches = appState.services.filter(s => {
          const matchCat = selectedCat === 'Todas' || s.category === selectedCat;
          const matchName = s.name.toLowerCase().includes(val);
          return matchCat && matchName;
        });

        if (matches.length === 0) {
          autoList.style.display = 'none';
          return;
        }

        autoList.innerHTML = matches.map(s => `
          <div class="autocomplete-item" data-name="${escapeHtml(s.name)}" data-price="${s.price}">
            <div>
              <div style="font-weight:600;">${escapeHtml(s.name)}</div>
              <div style="font-size:11px; color:var(--text-muted);">${escapeHtml(s.category)}</div>
            </div>
            <span style="font-weight:700; color:var(--color-accent);">${formatCurrency(s.price)}</span>
          </div>
        `).join('');

        autoList.style.display = 'block';

        autoList.querySelectorAll('.autocomplete-item').forEach(item => {
          item.addEventListener('click', () => {
            srvNameInput.value = item.getAttribute('data-name');
            document.getElementById('nq-service-price').value = item.getAttribute('data-price');
            autoList.style.display = 'none';
          });
        });
      });

      document.addEventListener('click', (e) => {
        if (!srvNameInput.contains(e.target) && !autoList.contains(e.target)) {
          autoList.style.display = 'none';
        }
      });
    }

    // Quote Details Handlers
    document.getElementById('qd-status-select')?.addEventListener('change', (e) => {
      updateQuoteStatus(e.target.value);
    });

    document.getElementById('qd-btn-delete')?.addEventListener('click', deleteCurrentQuote);
    document.getElementById('qd-btn-print-pdf')?.addEventListener('click', () => generateQuotePDF());
    document.getElementById('qd-btn-share-whatsapp')?.addEventListener('click', shareQuoteWhatsApp);

    // Service Form Handler
    document.getElementById('form-service')?.addEventListener('submit', saveService);

    // Category Creation Dialog
    document.getElementById('sf-btn-new-cat')?.addEventListener('click', () => showModal('modal-category-form'));
    document.getElementById('form-category')?.addEventListener('submit', (e) => {
      e.preventDefault();
      const newCatName = document.getElementById('cat-name-input').value.trim();
      if (newCatName) {
        const select = document.getElementById('sf-category-select');
        const opt = document.createElement('option');
        opt.value = newCatName;
        opt.textContent = newCatName;
        opt.selected = true;
        select.appendChild(opt);

        document.getElementById('cat-name-input').value = '';
        hideModal('modal-category-form');
        showToast('Categoría agregada');
      }
    });

    // Cloud Restore & Backup Handlers
    document.getElementById('btn-cloud-backup')?.addEventListener('click', () => {
      uploadToCloud(true);
    });
    document.getElementById('btn-cloud-restore')?.addEventListener('click', () => {
      syncFromCloud(true);
    });
  }

  // Execute App Initialization when DOM is ready
  document.addEventListener('DOMContentLoaded', init);

})();
