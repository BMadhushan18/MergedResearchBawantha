/// Configuration values for API clients.

// gateway host + port; adjust when deploying or testing on device network.
const String kGatewayHost = '10.137.119.235';
const int kGatewayPort = 8000;

// base url for the dineth service via gateway
const String kDinethApiBase = 'http://$kGatewayHost:$kGatewayPort/dineth';
