using Test
using DataShieldOpal

@test_nowarn dsConnect(
    Opal(),
    "server1";
    username="administrator",
    password="password",
    url="https://opal-demo.obiba.org",
)
con
