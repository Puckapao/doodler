// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AdventurerNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    uint256 public mintPrice;
    bool public mintingPaused;

    enum AdventurerClass { Adventurer, Squire, Magician, Thief, Cleric }

    struct ClassMultipliers {
        uint8 str;
        uint8 agi;
        uint8 vit;
        uint8 dex;
        uint8 intel;
        uint8 luk;
    }

    struct EquipmentMultipliers {
        uint8 weaponAttackMultiplier;
        uint8 weaponMagicAttackMultiplier;
    }

    struct Adventurer {
        string name;
        uint8 str;
        uint8 agi;
        uint8 vit;
        uint8 dex;
        uint8 intel;
        uint8 luk;
        uint256 statusPoints;
        uint256 level;
        uint256 uniqueId;
        address owner;
        string weaponName;
        uint8 equipmentWeaponAttack;
        uint8 equipmentWeaponMagicAttack;
        string armorName;
        uint8 equipmentArmorDef;
        AdventurerClass currentClass;
        uint256 accruedExp;
        uint256 lastAdventureTime;
        bool onAdventure;
    }

    mapping(AdventurerClass => ClassMultipliers) public classMultipliers;
    mapping(AdventurerClass => EquipmentMultipliers) public equipmentMultipliers;
    mapping(uint256 => Adventurer) private adventurers;

    event Minted(address indexed owner, uint256 indexed tokenId);
    event ExpClaimed(uint256 indexed tokenId, uint256 accruedExp);
    event LevelUp(uint indexed tokenId, uint newLevel, uint newStatusPoints);

    constructor(string memory baseTokenURI, uint256 _mintPrice) ERC721("PKP Adventurer", "PKADV") Ownable(msg.sender) {
        _baseTokenURI = baseTokenURI;
        mintPrice = _mintPrice;

        initializeClassMultipliers();
        initializeEquipmentMultipliers();
    }

    modifier notPaused() {
        require(!mintingPaused, "Minting is paused");
        _;
    }

    function mint(string memory name, uint256[6] memory stats) external payable notPaused {
        require(msg.value >= mintPrice, "Insufficient funds");
        require(bytes(name).length <= 10, "Name too long");
        require(sum(stats) <= 20, "Total status points exceed the limit");

        uint256 tokenId = ++_tokenIdCounter;
        _mint(msg.sender, tokenId);

        Adventurer storage newAdventurer = adventurers[tokenId];
        newAdventurer.name = name;
        newAdventurer.str = uint8(stats[0]);
        newAdventurer.agi = uint8(stats[1]);
        newAdventurer.vit = uint8(stats[2]);
        newAdventurer.dex = uint8(stats[3]);
        newAdventurer.intel = uint8(stats[4]);
        newAdventurer.luk = uint8(stats[5]);
        newAdventurer.statusPoints = uint256(20 - sum(stats));
        newAdventurer.level = 1;
        newAdventurer.uniqueId = tokenId;
        newAdventurer.owner = msg.sender;
        newAdventurer.weaponName = "";
        newAdventurer.equipmentWeaponAttack = 0;
        newAdventurer.equipmentWeaponMagicAttack = 0;
        newAdventurer.armorName = "";
        newAdventurer.equipmentArmorDef = 0;
        newAdventurer.currentClass = AdventurerClass.Adventurer;
        newAdventurer.accruedExp = 0;
        newAdventurer.lastAdventureTime = 0;
        newAdventurer.onAdventure = false;

        emit Minted(msg.sender, tokenId);
    }

    function initializeClassMultipliers() private {
        classMultipliers[AdventurerClass.Adventurer] = ClassMultipliers(10, 10, 10, 10, 10, 10);
        classMultipliers[AdventurerClass.Squire] = ClassMultipliers(15, 12, 12, 11, 10, 10);
        classMultipliers[AdventurerClass.Magician] = ClassMultipliers(10, 10, 10, 12, 18, 10);
        classMultipliers[AdventurerClass.Thief] = ClassMultipliers(11, 15, 10, 12, 10, 12);
        classMultipliers[AdventurerClass.Cleric] = ClassMultipliers(11, 11, 11, 11, 15, 11);
    }

    function initializeEquipmentMultipliers() private {
        equipmentMultipliers[AdventurerClass.Adventurer] = EquipmentMultipliers(12, 0);
        equipmentMultipliers[AdventurerClass.Squire] = EquipmentMultipliers(12, 0);
        equipmentMultipliers[AdventurerClass.Magician] = EquipmentMultipliers(0, 12);
        equipmentMultipliers[AdventurerClass.Thief] = EquipmentMultipliers(12, 0);
        equipmentMultipliers[AdventurerClass.Cleric] = EquipmentMultipliers(0, 12);
    }

    function sum(uint256[6] memory array) private pure returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < array.length; i++) {
            total += array[i];
        }
        return total;
    }

    function setClassMultiplier(AdventurerClass adventurerClass, ClassMultipliers calldata multipliers) external onlyOwner {
        classMultipliers[adventurerClass] = multipliers;
    }

    function setEquipmentMultiplier(AdventurerClass adventurerClass, EquipmentMultipliers calldata multipliers) external onlyOwner {
        equipmentMultipliers[adventurerClass] = multipliers;
    }

    function levelUp(uint256 tokenId) external {
        Adventurer storage adv = adventurers[tokenId];
        uint requiredExp = adv.level * 100;

        // Check if accruedExp is sufficient for leveling up
        require(adv.accruedExp > requiredExp, "Not enough accrued EXP");
            
        adv.accruedExp -= requiredExp;
        adv.level += 1;
        adv.statusPoints += adv.level * 3;

        // Emit a LevelUp event
        emit LevelUp(tokenId, adv.level, adv.statusPoints);
    }

    function upgradeStatuses(
        uint256 tokenId,
        uint256 str,
        uint256 agi,
        uint256 vit,
        uint256 dex,
        uint256 intel,
        uint256 luk
    ) external {
        Adventurer storage adv = adventurers[tokenId];
        uint256 totalUpgradePoints = str + agi + vit + dex + intel + luk;
        require(totalUpgradePoints <= adv.statusPoints, "Exceeds available status points");

        adv.statusPoints -= uint256(totalUpgradePoints);

        adv.str += uint8(str);
        adv.agi += uint8(agi);
        adv.vit += uint8(vit);
        adv.dex += uint8(dex);
        adv.intel += uint8(intel);
        adv.luk += uint8(luk);
    }


    function changeClass(uint256 tokenId, AdventurerClass newClass) external {
        Adventurer storage adv = adventurers[tokenId];
         require(
            newClass == AdventurerClass.Squire ||
                newClass == AdventurerClass.Magician ||
                newClass == AdventurerClass.Thief ||
                newClass == AdventurerClass.Cleric,
            "Invalid new class"
        );
        require(adv.level >= 10, "Adventurer level must be at least 10");
        require(adv.currentClass == AdventurerClass.Adventurer, "Adventurer can only change class if current class is Adventurer");
        adv.currentClass = newClass;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(_baseTokenURI, tokenId.toString()));
    }

    function adventure(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the adventurer");
        Adventurer storage adv = adventurers[tokenId];

        if (!adv.onAdventure) {
            uint256 currentTime = block.number;
            adv.lastAdventureTime = currentTime;
            adv.onAdventure = true;
        } else {
            adv.onAdventure = false;
            adv.lastAdventureTime = 0;
        }
    }

    function claimExp(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the adventurer");
        Adventurer storage adv = adventurers[tokenId];

        require(adv.onAdventure, "Adventurer has not started farming!");
        ClassMultipliers memory classMultiplier = classMultipliers[AdventurerClass(adv.currentClass)];
        uint256 statusMultiplier =
            ((adv.str * classMultiplier.str / 10) +
                (adv.agi * classMultiplier.agi / 10) +
                (adv.vit * classMultiplier.vit / 10) +
                (adv.dex * classMultiplier.dex / 10) +
                (adv.intel * classMultiplier.intel / 10) +
                (adv.luk * classMultiplier.luk / 10)) / 100;

        EquipmentMultipliers memory equipmentMultiplier = equipmentMultipliers[AdventurerClass(adv.currentClass)];

        uint256 expGain =
            (block.number - adv.lastAdventureTime) *
            (statusMultiplier +
                equipmentMultiplier.weaponAttackMultiplier +
                equipmentMultiplier.weaponMagicAttackMultiplier);

        adv.accruedExp = expGain;

        if (adv.onAdventure) {
            adv.onAdventure = false;
            adv.lastAdventureTime = 0;
        }

        emit ExpClaimed(tokenId, expGain);
    }

    function getAdventurerInfo(uint256 tokenId) external view returns (
        string memory name,
        uint256[6] memory stats,
        uint256 statusPoints,
        uint256 level,
        uint256 uniqueId,
        address owner,
        string[2] memory equipmentName,
        uint256[3] memory equipment,
        AdventurerClass currentClass,
        uint256 accruedExp,
        uint256 lastAdventureTime,
        bool onAdventure
    ) {
        require(ownerOf(tokenId) != address(0), "Adventurer does not exist");

        Adventurer storage adv = adventurers[tokenId];

        name = adv.name;
        stats = [uint256(adv.str), uint256(adv.agi), uint256(adv.vit), uint256(adv.dex), uint256(adv.intel), uint256(adv.luk)];
        statusPoints = adv.statusPoints;
        level = adv.level;
        uniqueId = adv.uniqueId;
        owner = adv.owner;
        equipmentName = [adv.weaponName, adv.armorName];
        equipment = [uint256(adv.equipmentWeaponAttack), uint256(adv.equipmentWeaponMagicAttack), uint256(adv.equipmentArmorDef)];
        currentClass = adv.currentClass;
        accruedExp = adv.accruedExp;
        lastAdventureTime = adv.lastAdventureTime;
        onAdventure = adv.onAdventure;
    }

    function viewExp(uint256 tokenId) external view returns (uint256 accruedExp) {
        require(ownerOf(tokenId) == msg.sender, "Not the owner of the adventurer");
        Adventurer storage adv = adventurers[tokenId];

        require(adv.onAdventure, "Adventurer has not started farming!");

        ClassMultipliers memory classMultiplier = classMultipliers[AdventurerClass(adv.currentClass)];
        uint256 statusMultiplier =
            ((adv.str * classMultiplier.str / 10) +
                (adv.agi * classMultiplier.agi / 10) +
                (adv.vit * classMultiplier.vit / 10) +
                (adv.dex * classMultiplier.dex / 10) +
                (adv.intel * classMultiplier.intel / 10) +
                (adv.luk * classMultiplier.luk / 10)) / 100;

        EquipmentMultipliers memory equipmentMultiplier = equipmentMultipliers[AdventurerClass(adv.currentClass)];

        accruedExp =
            (block.number - adv.lastAdventureTime) *
            (statusMultiplier +
                equipmentMultiplier.weaponAttackMultiplier +
                equipmentMultiplier.weaponMagicAttackMultiplier);
    }

    function getClassMultiplier(AdventurerClass adventurerClass) external view returns (ClassMultipliers memory) {
        ClassMultipliers memory currentClassMultiplier = classMultipliers[adventurerClass];
        return currentClassMultiplier;
    }

    function getEquipmentMultiplier(AdventurerClass adventurerClass) external view returns (EquipmentMultipliers memory) {
        EquipmentMultipliers memory currentEquipmentMultiplier = currentEquipmentMultipliers[adventurerClass];
        return currentEquipmentMultiplier;
    }
}
