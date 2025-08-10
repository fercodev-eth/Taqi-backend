// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {TaqiRoutes} from "../src/TaqiRoutes.sol";
import {TaqiNFT} from "../src/TaqiNFT.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// --- Mock Contrato para Simular USDC ---
// Creamos un contrato ERC20 falso para poder mintear tokens para nuestros usuarios de prueba.
contract MockUSDC is IERC20 {
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowances;
    uint256 public totalSupply;
    string public name = "Mock USDC";
    string public symbol = "mUSDC";
    uint8 public decimals = 6; // USDC usa 6 decimales

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }
    function allowance(address owner, address spender) external view returns (uint256) {
        return allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) external returns (bool) {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    function transfer(address to, uint256 amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowances[from][msg.sender] -= amount;
        balances[from] -= amount;
        balances[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
    // Función especial de prueba para darle fondos a los usuarios.
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
        totalSupply += amount;
    }
}


// --- Test Suite para TaqiRoutes ---
contract TaqiRoutesTest is Test {

    // Instancias de los contratos
    TaqiRoutes public taqiRoutes;
    TaqiNFT public taqiNFT;
    MockUSDC public usdc;

    // Direcciones de los actores de la prueba
    address public owner = address(0x1337); // Dueño de los contratos
    address public user = address(0x42);    // Un viajero
    address public oracle = address(0x07);  // El oráculo que valida las pruebas

    // Variables para las rutas
    uint256 public constant FREE_ROUTE_ID = 1;
    uint256 public constant PAID_ROUTE_ID = 2;
    uint256 public constant PAID_ROUTE_PRICE = 10 * 1e6; // 10 USDC

    // setUp se ejecuta antes de CADA función de prueba
    function setUp() public {
        // --- 1. Desplegar contratos como el 'owner' ---
        vm.startPrank(owner);

        usdc = new MockUSDC();
        taqiNFT = new TaqiNFT(owner); // El owner es el dueño inicial de TaqiNFT

        taqiRoutes = new TaqiRoutes(
            owner, // El owner es el dueño inicial de TaqiRoutes
            address(taqiNFT),
            address(usdc),
            oracle
        );

        // --- 2. Transferir la propiedad de TaqiNFT a TaqiRoutes ---
        // Este paso es CRUCIAL. TaqiRoutes debe poder mintear NFTs.
        taqiNFT.transferOwnership(address(taqiRoutes));

        // --- 3. Crear rutas de prueba ---
        taqiRoutes.createRoute("ipfs://free_route_metadata", 0, false); // Ruta 1 (gratis)
        taqiRoutes.createRoute("ipfs://paid_route_metadata", PAID_ROUTE_PRICE, false); // Ruta 2 (de pago)

        vm.stopPrank();

        // --- 4. Darle fondos al usuario ---
        // Le damos 100 mUSDC al usuario para que pueda pagar por las rutas.
        usdc.mint(user, 100 * 1e6);
    }

    // --- Pruebas de Configuración ---

    function test_InitialSetupIsCorrect() public {
        assertEq(taqiRoutes.owner(), owner, "El owner de TaqiRoutes es incorrecto");
        assertEq(taqiNFT.owner(), address(taqiRoutes), "TaqiRoutes no es el owner de TaqiNFT");
        assertEq(taqiRoutes.oracle(), oracle, "La direccion del Oraculo es incorrecta");
        assertEq(usdc.balanceOf(user), 100 * 1e6, "El usuario no recibio sus mUSDC iniciales");
    }

    // --- Pruebas de Flujo de Usuario ---

    function test_UserCanStartFreeChallenge() public {
        vm.startPrank(user);
        taqiRoutes.startChallenge(FREE_ROUTE_ID);
        vm.stopPrank();

        // No podemos verificar estados internos directamente, pero podemos inferir
        // que si no revirtió, la lógica básica funcionó.
        // La prueba de completado verificará el estado.
    }

    function test_UserCanStartAndPayForPaidChallenge() public {
        vm.startPrank(user);

        // Paso 1: El usuario debe APROBAR al contrato TaqiRoutes para gastar sus USDC.
        usdc.approve(address(taqiRoutes), PAID_ROUTE_PRICE);
        assertEq(usdc.allowance(user, address(taqiRoutes)), PAID_ROUTE_PRICE, "La aprobacion fallo");
        
        // Paso 2: El usuario inicia el reto.
        taqiRoutes.startChallenge(PAID_ROUTE_ID);
        vm.stopPrank();

        // Verificar que los fondos se transfirieron correctamente
        assertEq(usdc.balanceOf(user), (100 * 1e6) - PAID_ROUTE_PRICE, "El balance del usuario no disminuyo");
        assertEq(usdc.balanceOf(address(taqiRoutes)), PAID_ROUTE_PRICE, "El contrato no recibio los fondos");
    }

    // --- Pruebas de Flujo del Oráculo ---

    function test_OracleCanCompleteChallengeAndMintNFT() public {
        // El usuario empieza el reto primero
        vm.prank(user);
        taqiRoutes.startChallenge(FREE_ROUTE_ID);

        // Ahora el Oráculo confirma la completación
        vm.startPrank(oracle);
        taqiRoutes.completeChallenge(user, FREE_ROUTE_ID);
        vm.stopPrank();

        // Verificar que el NFT fue minteado y pertenece al usuario
        assertEq(taqiNFT.ownerOf(0), user, "El usuario no es el owner del NFT minteado");
        assertEq(taqiNFT.balanceOf(user), 1, "El balance de NFTs del usuario no es 1");
        
        // Verificar que el contador de rutas completadas se actualizó
        assertTrue(taqiRoutes.userCompletedRoutes(user, FREE_ROUTE_ID), "La ruta no se marco como completada");
        assertEq(taqiRoutes.userSeasonCompletions(user), 1, "El contador de temporada no se incremento");
    }

    // --- Pruebas de Casos de Fallo (Reverts) ---

    function test_Fail_UserCannotCreateRoute() public {
        vm.startPrank(user);
        // Esperamos que la transacción revierta con el mensaje de Ownable
        vm.expectRevert("Ownable: caller is not the owner");
        taqiRoutes.createRoute("ipfs://hacker_route", 0, false);
        vm.stopPrank();
    }

    function test_Fail_NonOracleCannotCompleteChallenge() public {
        vm.prank(user);
        taqiRoutes.startChallenge(FREE_ROUTE_ID);

        // El propio usuario intenta completar su reto (debería fallar)
        vm.startPrank(user);
        vm.expectRevert("Only the oracle can call this function");
        taqiRoutes.completeChallenge(user, FREE_ROUTE_ID);
        vm.stopPrank();
    }

    function test_Fail_UserCannotStartPaidChallengeWithoutApproval() public {
        vm.startPrank(user);
        // El usuario no ha llamado a `approve`, por lo que la transferencia fallará.
        // ERC20: transfer amount exceeds allowance
        vm.expectRevert(); 
        taqiRoutes.startChallenge(PAID_ROUTE_ID);
        vm.stopPrank();
    }

    function test_Fail_CannotCompleteChallengeTwice() public {
        // Flujo de completado normal
        vm.prank(user);
        taqiRoutes.startChallenge(FREE_ROUTE_ID);
        vm.prank(oracle);
        taqiRoutes.completeChallenge(user, FREE_ROUTE_ID);

        // El oráculo intenta completarlo de nuevo para el mismo usuario
        vm.startPrank(oracle);
        vm.expectRevert("Route already completed by user");
        taqiRoutes.completeChallenge(user, FREE_ROUTE_ID);
        vm.stopPrank();
    }
}