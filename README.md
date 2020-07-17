# Tire pressure system for Farming Simulator 19

![For Farming Simulator 19](https://img.shields.io/badge/Farming%20Simulator-19-FF7C00.svg) [![Releases](https://img.shields.io/github/release/stijnwop/guidanceSteering.svg)](https://github.com/stijnwop/guidanceSteering/releases)

Make sure to add the following (besides the specialization entry) to your modDesc:

The registering of actions.
```xml
<actions>
    <action name="TP_AXIS_PRESSURE" axisType="FULL"/>
    <action name="TP_TOGGLE_PRESSURE" axisType="HALF"/>
</actions>
```

The binding of inputs (which key maps to what action).
```xml
<inputBinding>
    <actionBinding action="TP_TOGGLE_PRESSURE">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_p"/>
    </actionBinding>
    <actionBinding action="TP_AXIS_PRESSURE">
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_pageup" axisComponent="+"/>
        <binding device="KB_MOUSE_DEFAULT" input="KEY_lctrl KEY_pagedown" axisComponent="-"/>
    </actionBinding>
</inputBinding>
```

The localisation entry.
```xml
<l10n>
    <text name="information_tirePressure">
        <en>Tire pressure [target: %1.2f bar] [current: %1.2f bar]</en>
        <de>Reifenluftdruck [Soll: %1.2f bar] [Ist: %1.2f bar]</de>
        <es>Presión Neumático [Fijar en: %1.2f bar] [Actual: %1.2f bar]</es>
        <it>Pressione pneumatico [obiett.: %1.2f bar] [attuale: %1.2f bar]</it>
    </text>
    <text name="action_toggleTirePressure">
        <en>Toggle pressure</en>
        <de>Druck ändern</de>
        <es>Cambiar presión</es>
        <it>Modifica pressione</it>
    </text>
    <text name="input_TP_TOGGLE_PRESSURE">
        <en>Update pressure</en>
        <de>Druck aktualisieren</de>
        <es>Actualizar presión</es>
        <it>Aggiorna pressione</it>
    </text>
    <text name="input_TP_AXIS_PRESSURE_1">
        <en>Inflate</en>
        <de>Aufpumpen</de>
        <es>Inflar</es>
        <it>Gonfia</it>
    </text>
    <text name="input_TP_AXIS_PRESSURE_2">
        <en>Deflate</en>
        <de>Ablassen</de>
        <es>Desinflar</es>
        <it>Sgonfia</it>
    </text>
</l10n>
```

In the vehicle xml you can configure the following (which are all OPTIONAL):
- `min`: the minimum kPa
- `max`: the maximum kPa
- `configurationName`: if you want to activate tire pressure for specific configurations you can use this entry to specify the configuration. (e.g. `wheels`)
- `configurationIndices`: the indexes of the given `configurationName` that should activate the tire pressure.

>PLEASE NOTE: `configurationIndices` can only be used when `configurationName` is set.

Below an example entry for your vehicle XML.
Don't blindly copy paste as you will have to change the attributes yourself to the correct values or remove them when not needed.
```xml
If you only want to active it for a specific configuration/configurations you will have to set the configurationName and configurationIndices attributes.
<tirePressure min="X (OPTIONAL -> DEFAULT 80)" max="X (OPTIONAL -> DEFAULT 180)" configurationName="wheels (OPTIONAL)" configurationIndices="2 8 9 (INDEXES OF THE CONFIGURATION)">
    <sounds>
        <air template="DEFAULT_SOWING_AIR_BLOWER">
        <volume indoor="0.4" outdoor="0.85" />
            <pitch indoor="1.0" outdoor="1.0" >
                <modifier type="VALVE_LOAD" value="0.00" modifiedValue="0.80" />
                <modifier type="VALVE_LOAD" value="1.00" modifiedValue="1.20" />
            </pitch>
        </air>
    </sounds>
</tirePressure>
```

### Please read this when your vehicle has vehicleTypeConfigurations! 
A common mistake is that people forget to change the vehicleTypes in the vehicleTypeConfigurations. When those configurations are present the mod will default to the first configuration given, resulting in any custom vehicle type you defined to be overwritten.

So, make sure you change them to your new vehicleType!
