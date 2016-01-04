# raimo-twilight

Fades some of my Houm.IO lights in when the sun rises and out when the time sets.

## Install and run

First

    npm install -g coffee-script
    npm install

Then create a config file `houm-config.js` where you configure your Houm.IO
sitekey and light ids to fade, and your latitude/longitude that are used for
getting sunset/sunrise times from [Sunrise Sunset API](http://sunrise-sunset.org/).

Here's an example config file.

```js
module.exports = { 
  latitude: 60.1695200,
  longitude: 24.9354500,
  siteKey: "mysitekey", 
  lights: [{
    id: 'mylightid'
  }]
}
```

You can find the light ids by starting the server once: it'll list available lights
on the console.

To start the server, just

  ./server.coffee
