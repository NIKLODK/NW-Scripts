Config = {}

Config.Ped = {
    model = 's_m_m_dockwork_01',
    coords = vec4(-797.7985, -1512.0773, 1.5952, 293.5880)
}

Config.Target = {
    icon = 'fa-solid fa-ship',
    label = 'Åben bådforhandler'
}

Config.Blip = {
    enabled = true,
    sprite = 410,
    color = 3,
    scale = 0.8,
    shortRange = true,
    label = 'Bådforhandler'
}

Config.Rental = {
    enabled = true,
    pricePercent = 15,
    minimumPrice = 2500,
    durationMinutes = 30,
    spawn = vec4(-806.2776, -1497.5739, -0.4745, 111.3368)
}

Config.VehicleType = 'sea'
Config.PurchasedBoatGarage = 'Boats'
Config.DefaultGarage = 'boat_garage'
Config.PlatePrefix = 'BOAT'
Config.Locale = {
    not_enough_cash = 'Du har ikke nok kontanter.',
    not_enough_bank = 'Du har ikke penge nok paa kortet.',
    purchase_success = 'Du købte %s for $%s. Nummerplade: %s',
    purchase_failed = 'Købet fejlede. Prøv igen.',
    busy = 'Vent et øje blik...',
    menu_title = 'Bådforhandler',
    menu_subtitle = 'Vælg en baad',
    action_title = 'Vælg handling',
    action_subtitle = '%s - $%s',
    buy_option = 'Køb',
    rent_option = 'Lej',
    payment_title = 'Betaling',
    payment_subtitle = 'Vælg betalingsmetode',
    pay_cash = 'Betal kontant',
    pay_bank = 'Betal med kort',
    rent_payment_title = 'Lejebetaling',
    rent_success = 'Du lejede %s for $%s i %s minutter.',
    rent_failed = 'Lejen fejlede. Prøv igen.',
    rent_disabled = 'Leje er ikke aktiveret.',
    rental_active = 'Du har allerede en aktiv lejebaad.',
    return_rental = 'Aflever lejebaad',
    rental_returned = 'Lejebaad afleveret.',
    rental_expired = 'Din lejebaad er udloebet.',
    rental_removed = 'Din lejebaad blev fjernet.',
    rental_model_missing = 'Kunne ikke loade baadmodellen.'
}

Config.Boats = {
    { model = 'dinghy', label = 'Dinghy', price = 15000 },
    { model = 'jetmax', label = 'Jetmax', price = 180000 },
    { model = 'seashark', label = 'Seashark', price = 22000 },
    { model = 'speeder', label = 'Speeder', price = 95000 },
    { model = 'squalo', label = 'Squalo', price = 78000 },
    { model = 'suntrap', label = 'Suntrap', price = 52000 },
    { model = 'toro', label = 'Toro', price = 340000 },
    { model = 'tropic', label = 'Tropic', price = 120000 },
    { model = 'longfin', label = 'Longfin', price = 240000 }
}
