#pragma once
#include <math.h>
// Catalog admission is independent of the player's source/network deadlines.
// A cold catalog must finish before a diagnostic can choose its public film.
typedef enum { RWCatalogWaiting, RWCatalogReady, RWCatalogExpired } RWCatalogAdmission;
static inline RWCatalogAdmission RWPlaybackCatalogAdmission(int ready,double elapsed) {
    if(!isfinite(elapsed)||elapsed<0||elapsed>=35)return RWCatalogExpired;
    return ready?RWCatalogReady:RWCatalogWaiting;
}
