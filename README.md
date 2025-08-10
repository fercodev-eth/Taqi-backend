¡Por supuesto! Un buen `README.md` es esencial para cualquier proyecto en GitHub. Hace que sea fácil para otros (y para tu futuro yo) entender la arquitectura, el propósito y cómo interactuar con los contratos.

Aquí tienes un `README.md` completo y detallado. Está escrito en Markdown, así que puedes copiarlo y pegarlo directamente en un archivo `README.md` en la raíz de tu repositorio de Git.

---

# TAQI - Backend de Contratos Inteligentes

Este repositorio contiene los contratos inteligentes en Solidity que impulsan la DApp de viajes gamificada **TAQI**. La arquitectura está diseñada para ser segura, eficiente en gas y escalable, combinando lógica on-chain para los activos y reglas críticas con una infraestructura off-chain para datos pesados y lógica del mundo real.

## Tabla de Contenidos

1.  [Arquitectura del Sistema](#arquitectura-del-sistema)
    *   [Componentes On-Chain](#componentes-on-chain-solidity)
    *   [Componentes Off-Chain](#componentes-off-chain-servidor--ipfs)
2.  [Contratos Inteligentes](#contratos-inteligentes)
    *   [`TaqiNFT.sol`](#1-taqinftsol---el-nft-coleccionable)
    *   [`TaqiRoutes.sol`](#2-taqiroutessol---el-cerebro-de-la-aplicación)
3.  [Flujo de Interacción](#flujo-de-interacción)
4.  [Desarrollo y Pruebas (Foundry)](#desarrollo-y-pruebas-foundry)
    *   [Instalación](#instalación)
    *   [Compilar](#compilar)
    *   [Probar](#probar)
    *   [Desplegar](#desplegar)

---

## Arquitectura del Sistema

El sistema TAQI utiliza una arquitectura híbrida para combinar la seguridad de la blockchain con la flexibilidad y el bajo costo de los sistemas tradicionales.

### Componentes On-Chain (Solidity)

-   **Gestión de Propiedad de Activos**: Los NFTs coleccionables (`TaqiNFT`) son tokens ERC-721A, garantizando que la propiedad es verificable y transferible en la blockchain.
-   **Lógica de Pagos y Recompensas**: El contrato `TaqiRoutes` gestiona de forma segura los pagos en USDC por rutas premium y la distribución de los NFTs de recompensa.
-   **Reglas Inmutables**: La definición de las rutas, sus precios y las recompensas asociadas se almacenan on-chain, asegurando transparencia y resistencia a la censura.
-   **Verificación Descentralizada**: El patrón de "Oráculo" se utiliza para conectar eventos del mundo real (completar una ruta) con acciones on-chain (mintear un NFT).

### Componentes Off-Chain (Servidor + IPFS)

-   **Metadatos**: Todos los datos pesados, como imágenes de rutas, descripciones, y los atributos de los NFTs (imágenes, animaciones), se almacenan en **IPFS** para garantizar la persistencia descentralizada sin sobrecargar la blockchain.
-   **Lógica de Negocio Compleja**: Un servidor backend tradicional se encarga de tareas como:
    -   Recomendaciones de rutas personalizadas basadas en GPS e intereses.
    -   Verificación de pruebas (fotos/videos) para el Oráculo.
    -   Indexación de datos para leaderboards y historiales de viaje (usando The Graph).
-   **Integración Fiat-Crypto**: Los servicios de On-Ramp (como MoonPay, Transak) se integran en el frontend para facilitar la compra de USDC por parte de los usuarios.

---

## Contratos Inteligentes

El núcleo del sistema se compone de dos contratos principales que trabajan en conjunto.

### 1. `TaqiNFT.sol` - El NFT Coleccionable

Este contrato define el coleccionable digital que los usuarios reciben como recompensa.

-   **Estándar:** `ERC721A` de Chiru Labs. Es una optimización del ERC-721 que permite mintear múltiples NFTs con un costo de gas significativamente reducido, ideal para recompensas a gran escala.
-   **Propiedad:** El contrato implementa `Ownable` de OpenZeppelin. En nuestro sistema, la propiedad de este contrato se transfiere al contrato `TaqiRoutes` después del despliegue. Esto crea una barrera de seguridad: **solo `TaqiRoutes` puede mintear nuevos NFTs**.

#### Funciones Clave:

-   `constructor(address initialOwner)`: Inicializa el contrato, estableciendo el nombre ("Taqi Collectible"), el símbolo ("TAQI") y asignando un dueño inicial.
-   `safeMint(address to)`: **(Solo para el `owner`)** Crea (mintea) un nuevo NFT y lo asigna a la dirección del usuario `to`. Esta función es llamada por `TaqiRoutes` cuando un usuario completa un reto.
-   `setBaseURI(string calldata baseURI)`: **(Solo para el `owner`)** Establece la URL base para los metadatos de los NFTs. Típicamente, apunta a una carpeta en IPFS (ej: `ipfs://CID/`). El metadata de un token específico se resuelve concatenando el ID del token (ej: `ipfs://CID/1.json`).

### 2. `TaqiRoutes.sol` - El Cerebro de la Aplicación

Este es el contrato principal con el que interactúan los usuarios y el oráculo. Gestiona toda la lógica de rutas, pagos y recompensas.

-   **Seguridad:** Implementa `Ownable` para las funciones administrativas y `ReentrancyGuard` para proteger las funciones de pago contra ataques de reentrada.

#### Estructuras de Datos:

-   `struct Route`: Almacena la información esencial de cada ruta on-chain:
    -   `id`: Identificador único.
    -   `metadataURI`: Puntero a IPFS con los detalles completos de la ruta.
    -   `usdcPrice`: Precio en USDC para desbloquear la ruta (0 si es gratis).
    -   `isSpecialEvent`: Booleano para marcar rutas de eventos especiales.
    -   `isActive`: Permite al administrador activar o desactivar rutas.

#### Funciones de Administración (`onlyOwner`)

-   `createRoute(...)`: Permite al dueño del contrato crear nuevas rutas, definiendo su precio y metadatos.
-   `setOracle(address _newOracle)`: Permite al dueño cambiar la dirección de la wallet del Oráculo.
-   `withdrawUSDC()`: Permite al dueño retirar los fondos en USDC acumulados en el contrato por la compra de rutas.

#### Funciones para el Usuario

-   `startChallenge(uint256 _routeId)`:
    -   El usuario llama a esta función para comenzar una ruta.
    -   Verifica que la ruta no haya sido completada antes por el usuario.
    -   Si la ruta es de pago (`usdcPrice > 0`), transfiere la cantidad requerida de USDC desde la wallet del usuario al contrato. **Requiere que el usuario haya aprobado previamente al contrato para gastar sus USDC.**

#### Función para el Oráculo (`onlyOracle`)

-   `completeChallenge(address _user, uint256 _routeId)`:
    -   Esta función **NO** es llamada por el usuario final. Es llamada por el servidor backend (el Oráculo) después de verificar la prueba del mundo real (foto/video).
    -   Marca la ruta como completada para ese usuario, evitando recompensas dobles.
    -   Incrementa el contador de rutas completadas del usuario para el leaderboard.
    -   Llama a `taqiNFT.safeMint(_user)` para acuñar y entregar el NFT de recompensa al usuario.

---

## Flujo de Interacción

1.  **Admin:** El dueño del contrato llama a `createRoute` para añadir nuevas rutas al sistema.
2.  **Usuario (Frontend):**
    -   El usuario ve las rutas disponibles. Los metadatos se cargan desde IPFS.
    -   Para una ruta de pago, la UI solicita al usuario una transacción `approve` en el contrato de USDC, permitiendo que `TaqiRoutes` gaste la cantidad necesaria.
    -   El usuario presiona "Empezar Reto", lo que llama a `startChallenge(_routeId)`.
3.  **Usuario (Mundo Real):** El usuario completa la ruta y sube una prueba (foto) a un servidor backend.
4.  **Oráculo (Backend):**
    -   El servidor verifica la prueba.
    -   Si es válida, el servidor (actuando como el Oráculo) llama a `completeChallenge(userAddress, routeId)` en el contrato `TaqiRoutes`.
5.  **Blockchain:**
    -   `TaqiRoutes` verifica que la llamada provenga del Oráculo.
    -   Llama a `TaqiNFT` para mintear el coleccionable directamente en la wallet del usuario.
    -   Se emiten eventos (`ChallengeCompleted`) que pueden ser escuchados por el frontend o servicios de indexación para actualizar la UI en tiempo real.

---

## Desarrollo y Pruebas (Foundry)

Este proyecto utiliza [Foundry](https://github.com/foundry-rs/foundry) para la compilación, pruebas y despliegue de contratos.

### Instalación

1.  Clona el repositorio: `git clone <URL_DEL_REPO>`
2.  Entra en la carpeta: `cd <NOMBRE_DEL_REPO>`
3.  Instala las dependencias (librerías): `forge install`

### Compilar

Para compilar los contratos y asegurarte de que no hay errores de sintaxis, ejecuta:

```bash
forge build
```

### Probar

Hemos incluido un completo suite de pruebas en la carpeta `test/`. Para ejecutar todas las pruebas:

```bash
forge test
```

Para obtener un informe detallado de cobertura de código:

```bash
forge coverage
```

### Desplegar

Utiliza el script de despliegue ubicado en `script/DeployTaqi.s.sol`. Asegúrate de tener un archivo `.env` configurado con tu `PRIVATE_KEY` y `RPC_URL`.

**Ejemplo de despliegue en la red de prueba Sepolia:**

```bash
forge script script/DeployTaqi.s.sol:DeployTaqi --rpc-url sepolia --broadcast --verify -vvvv
```