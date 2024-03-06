local classDB = {
    clones_soldier = {
        displayName = "clones_soldier_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_stuntman_backpack/char_shared_outfit_stuntman_backpack.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    },
    clones_heavy = {
        displayName = "clones_heavy_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_demolition_backpack/char_shared_outfit_demolition_backpack.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            secondary = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            equipment1 = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            equipment2 = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
        }
    },
    clones_sniper = {
        displayName = "clones_sniper_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_golf_backpack/char_shared_outfit_golf_backpack.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    },
    clones_engineer = {
        displayName = "clones_engineer_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_engineer_backpack/char_shared_outfit_engineer_backpack.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    },
    cis_soldier = {
        displayName = "cis_soldier_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_stuntman_hat/char_male_outfit_stuntman_hat.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    },
    cis_heavy = {
        displayName = "cis_heavy_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_demolition_hat/char_shared_outfit_demolition_hat.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            secondary = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            equipment1 = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
            equipment2 = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b",
        }
    },
    cis_sniper = {
        displayName = "cis_sniper_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_golf_hat/char_male_outfit_golf_hat.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    },
    cis_engineer = {
        displayName = "cis_engineer_name",
        model = "$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_engineer_hat/char_male_outfit_engineer_hat.rend",
        health = 100,
        speed = 1,
        weapons = {
            primary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            secondary = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment1 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
            equipment2 = "c5ea0c2f-185b-48d6-b4df-45c386a575cc",
        }
    }
}

function GetClassData(class)
    return classDB[class] or {}
end



print("CLASSES LOADED")