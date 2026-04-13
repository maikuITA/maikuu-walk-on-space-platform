local CUSTOM_INPUT_NAME = "sp_hub_interaction"
local HUB_SEARCH_RADIUS = 100
local HUB_OFFSET = 40

local MSG_NOT_ON_PLATFORM = "[Walk-on-space] You can only use Enter on the hub when you are on a space platform."
local MSG_NO_HUB_NEARBY = "[Walk-on-space] No space-platform-hub found nearby."
local MSG_ENTERED_HUB = "[Walk-on-space] Entering space-platform-hub. Press Enter to exit."
local MSG_EXITED_HUB = "[Walk-on-space] Exiting space-platform-hub."
local MSG_CANNOT_EXIT = "[Walk-on-space] Cannot exit: invalid return position. Leave one free tile around the hub and try again."
local MSG_NOT_ON_REMOTE_VIEW = "[Walk-on-space] You cannot enter or exit the hub while in remote view. Press 'Esc' and the try again."

local CURRENT_CONTROLLER = "get-current-controller-type"

local function ensure_state_tables()
        storage.hub_players = storage.hub_players or {}
        storage.pending_teleport = storage.pending_teleport or {}
end

-- Restituisce l'hub piu vicino al giocatore entro il raggio definito.
local function get_nearest_hub(player)
    local position = player.position
    local surface = player.surface
    local hubs = surface.find_entities_filtered{
        name = "space-platform-hub",
        position = position,
        radius = HUB_SEARCH_RADIUS
    }
    local closest_hub = nil
    local closest_distance = math.huge
    for _, hub in pairs(hubs) do
        local distance = ((hub.position.x - position.x) ^ 2 + (hub.position.y - position.y) ^ 2) ^ 0.5
        if distance < closest_distance then
            closest_distance = distance
            closest_hub = hub
        end
    end
        return closest_hub
end

-- Funziona che trova un punto safe per l'uscita dall'hub, controllando se è possibile posizionare il player in quella posizione
local function find_safe_exit_position(surface, reference_position)
    local preferred_position = {x = reference_position.x, y = reference_position.y}
    return surface.find_non_colliding_position("character", preferred_position, HUB_OFFSET, 0.25)
end

-- Funzione che gestisce l'evento di toggle dell'hub
local function on_toggle_hub(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then
        return
    end

    ensure_state_tables()

    local nearby_hub = get_nearest_hub(player)
    local state = storage.hub_players[player.index]

    if state then --se sono già in un hub, allora esco
        -- Creo il player
        local character = nil
        if player.character and player.character.valid then
            character = player.character
        else
            player.create_character()
            character = player.character
        end
        -- Controllo se il player è valido
        if not (character and character.valid) then
            storage.hub_players[player.index] = nil
            storage.pending_teleport[player.index] = nil
            --player.print(MSG_CANNOT_EXIT)
            return
        end
        -- Assegno il controller al player
        player.set_controller{ type = defines.controllers.character, character = character }
        -- Trovo la posizione valida più vicina
        local exit_position = find_safe_exit_position(player.surface, player.position)
        if not exit_position then
            player.print(MSG_CANNOT_EXIT)
            --player.print("=" .. exit_position)
            return
        end
        -- Teleporto il player fouri dall'hub ({5.1, 5.1} is out)
        player.teleport(exit_position, player.surface)
        storage.hub_players[player.index] = nil
        storage.pending_teleport[player.index] = nil
        --player.print(MSG_EXITED_HUB)
        return
    else ------------------------------------------------------------------ altrimenti si entra nell'hub
        -- Controllo se la surface è valida
        if not (player.surface and player.surface.valid and player.surface.platform) then
            --player.print(MSG_NOT_ON_PLATFORM)
            return
        end
        -- Se non ho trovato un hub vicino, return
        if not nearby_hub then
            --player.print(MSG_NO_HUB_NEARBY)
            return
        end
        -- Controllo se il platform è valido
        local platform = nearby_hub.surface.platform or player.surface.platform
        if not platform then
            --player.print(MSG_NOT_ON_PLATFORM)
            return
        end
        -- salvo tutte le informazioni importanti
        storage.hub_players[player.index] = {
            outside_surface_name = player.surface.name,
            outside_position = {x = player.position.x, y = player.position.y},
            hub_unit_number = nearby_hub.unit_number,
            character = player.character
        }
        -- Teleporto il player nell'hub
        player.teleport(nearby_hub.position, platform.surface)
        player.set_controller{ type = defines.controllers.remote }
        storage.pending_teleport[player.index] = nil
        --player.print(MSG_ENTERED_HUB)
        return
    end

    -- Se mi trovo in remote view, non faccio nulla
    --if player.controller_type ~= defines.controllers.remote then
        
    --else
        ----player.print(MSG_NOT_ON_REMOTE_VIEW)
        --return
    --end
end

local function on_init_or_configuration_changed()
    ensure_state_tables()
end

local function getControllerType(event)
    local player = game.get_player(event.player_index)
    if not (player and player.valid) then
        return
    end

    --player.print("Current controller type: " .. player.controller_type)
    --player.print("Current position: x=" .. player.position.x .. ", y=" .. player.position.y)
end

script.on_init(on_init_or_configuration_changed)
script.on_configuration_changed(on_init_or_configuration_changed)
script.on_event(CUSTOM_INPUT_NAME, on_toggle_hub)
script.on_event(CURRENT_CONTROLLER, getControllerType)