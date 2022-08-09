
const ReserveAssets = {
    DAI: {
        contractFactory: 'DAI',
        reserveName: 'DAI',
        underlyingAddress: '0x5147fBBB26AD307DBF562EE242BFA3eF44fb3145',
        PriceFeed: '0xE4eE17114774713d2De0eC0f035d4F7665fc025D'
    },
    BTCB: {    
        contractFactory: 'BTCB',
        reserveName: 'BTCB',
        underlyingAddress: '0x37502cDeAfC39662c9F15FC2135cC5Ff4fa6Da04',
        PriceFeed: '0x5741306c21795FdCBb9b265Ea0255F499DFe515C',
    },
    BUSD: {    
        contractFactory: 'BUSD',
        reserveName: 'BUSD',
        underlyingAddress: '0x522d378d2e1EeCeEB332b3C18D473cf00526C888',
        PriceFeed: '0x9331b55D9830EF609A2aBCfAc0FBCE050A52fdEa',
    }
}


module.exports = {
    ReserveAssets
};
