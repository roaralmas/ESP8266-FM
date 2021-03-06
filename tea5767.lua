-- Original: https://github.com/na1pir/tea5767-esp8266-nodemcu/tree/master
-- Added fetch of signal strength from FM Module
-- 20150719/ralm
-- -------------------
wifi.setmode(wifi.STATION)
wifi.sta.config("ssid","passwd")
wifi.sta.connect()
tmr.delay(1000000)
print (wifi.sta.getip())
id=0
sda=3
scl=4
dev_addr=0x60
freq=887
signal_strength=0
i2c.setup(id,sda,scl,i2c.SLOW)

--calculate parameters and write frequency to tea5767
function set_freq(freq)
  frequency = 4 * (freq * 100000 + 225000) / 32768;
  frequencyH = frequency / 256;
  frequencyL = bit.band(frequency,0xff);
  i2c.start(id)
  i2c.address(id, dev_addr ,i2c.TRANSMITTER)
  i2c.write(id,frequencyH)
  i2c.write(id,frequencyL)
  i2c.write(id,0xB0)
  i2c.write(id,0x10)
  i2c.write(id,0)
  i2c.stop(id)
  tmr.delay(10000)
  get_info();
end

function get_info()
  i2c.start(id)
  i2c.address(id, dev_addr ,i2c.RECEIVER)
  data = i2c.read(id, 5)
  i2c.stop(id)
  local strength = string.sub(data,4,4);
  local str2 = string.byte(strength);
  signal_strength = str2/16;
end


set_freq(freq);

srv=net.createServer(net.TCP)
srv:listen(80,function(conn)
    conn:on("receive", function(client,request)
        local buf = "";
        local _, _, method, path, vars = string.find(request, "([A-Z]+) (.+)?(.+) HTTP");
        if(method == nil)then
            _, _, method, path = string.find(request, "([A-Z]+) (.+) HTTP");
        end
        local _GET = {}
        if (vars ~= nil)then
            for k, v in string.gmatch(vars, "(%w+)=(%w+)&*") do
                _GET[k] = v
            end
        end
		buf = buf.."<h1> ESP8266 + TEA5767 fm radio</h1>";
        buf = buf.."<p>Modify Frequency for 1: <a href=\"?pin=m\"><button>-</button></a>&nbsp;<a href=\"?pin=p\"><button>+</button></a></p>";
        buf = buf.."<p>Modify Frequency for 10: <a href=\"?pin=mm\"><button>-10</button></a>&nbsp;<a href=\"?pin=pp\"><button>+10</button></a></p>";
        if(_GET.pin == "m")then
              freq=freq-1
              if(freq<875)then
				freq=875;
			  end
              set_freq(freq);
        elseif(_GET.pin == "p")then
              freq=freq+1
              if(freq>1080)then
				freq=1080;
			  end
              set_freq(freq);
        elseif(_GET.pin == "pp")then
              freq=freq+10
              if(freq>1080)then
				freq=1080;
			  end
              set_freq(freq);
        elseif(_GET.pin == "mm")then
              freq=freq-10;
              if(freq<875)then
				freq=875;
			  end
			  set_freq(freq);
        end
        _freq=tostring(freq);
        _strength=tostring(signal_strength);
        
        buf = buf.."Frequency:";
        buf = buf.._freq;
        buf = buf.."<br>Strength:".._strength.."/15";
        buf = buf.."</p>";

        client:send(buf);
        client:close();
        collectgarbage();
    end)
end)
