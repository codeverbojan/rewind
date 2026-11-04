// Card and detail freshness must agree when a verified file has no usable URL.
// Also repair old cache entries that advertised seven days after a failed photo
// request. This does not shorten complete or explicitly image-less records.
static double MEntityExpiry(NSDictionary *record,NSString *field) {
    double expiry=[record[field]doubleValue];
    if([field isEqual:@"expires"]&&!record[field])expiry=[record[@"at"]doubleValue]+7*86400;
    if(MT(record[@"imageFile"]).length&&!MT(record[@"image"]).length){double checked=[record[@"photoCheckedAt"]?:record[@"at"]doubleValue];expiry=MIN(expiry,checked+900);}
    return expiry;
}
