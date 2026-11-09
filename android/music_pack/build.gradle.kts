// Play Asset Delivery pack: the music sounds in sound_packs/music (symlinked as
// src/main/assets). "fast-follow" = Google Play downloads it automatically
// right after the app is installed.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("music")
    dynamicDelivery {
        deliveryType.set("fast-follow")
    }
}
