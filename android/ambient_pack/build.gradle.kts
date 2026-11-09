// Play Asset Delivery pack: the ambient sounds in sound_packs/ambient (symlinked as
// src/main/assets). "fast-follow" = Google Play downloads it automatically
// right after the app is installed.
plugins {
    id("com.android.asset-pack")
}

assetPack {
    packName.set("ambient")
    dynamicDelivery {
        deliveryType.set("fast-follow")
    }
}
