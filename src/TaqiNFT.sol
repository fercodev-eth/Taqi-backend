// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "erc721a/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TaqiNFT
 * @dev Contrato para los NFTs coleccionables de TAQI.
 * El único que puede crear (mintear) NFTs es el contrato TaqiRoutes.
 */
contract TaqiNFT is ERC721A, Ownable {
    
    // La URI base para todos los metadatos de los NFTs (apunta a IPFS/Arweave).
    string private _baseTokenURI;

    /**
     * @dev El constructor ahora acepta un `initialOwner` y lo pasa al constructor de Ownable.
     * También llama al constructor de ERC721A con el nombre y símbolo del token.
     */
    constructor(address initialOwner) 
        ERC721A("Taqi Collectible", "TAQI")
        Ownable(initialOwner) 
    {
        // El cuerpo del constructor puede estar vacío si no se necesita lógica adicional.
    }

    /**
     * @dev Función para que el dueño (TaqiRoutes) cree un nuevo NFT para un usuario.
     * @param to La dirección del usuario que recibirá el NFT.
     */
    function safeMint(address to) public onlyOwner {
        // _safeMint es una función de ERC721A.
        // El segundo parámetro '1' indica que se crea 1 solo token.
        _safeMint(to, 1);
    }

    /**
     * @dev Establece la URI base donde se almacenan los metadatos.
     * Ejemplo: "ipfs://Qmabc.../" -> El metadata del token 1 estará en "ipfs://Qmabc.../1.json"
     */
    function setBaseURI(string calldata baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }


    /**
     * @dev Devuelve la URI base para los metadatos.
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }
}