/////////////////////////////////////////////////////////////////////////////////////
//
// This class configures and manages the connection to the OpenBCI Bitalino.
//
//
//
//
//
//
//
/////////////////////////////////////////////////////////////////////////////////////


//------------------------------------------------------------------------
//                       Global Functions
//-------------------------------------------------------------------------

class Bitalino {
    final static char BITALINO_BOOTLOADER_MODE = '>';

    final static int NUM_ACCEL_DIMS = 3;

    private int nEEGValuesPerPacket = NCHAN_BITALINO; // Defined by the data format sent by cyton boards
    private int nAuxValuesPerPacket = NUM_ACCEL_DIMS; // Defined by the arduino code

    private final float fsHzBLE = 100.0f;

    private final float MCP3912_Vref = 1.2f;  // reference voltage for ADC in MCP3912 set in hardware
    private final float MCP3912_gain = 1.0;  //assumed gain setting for MCP3912.  NEEDS TO BE ADJUSTABLE JM
    private float scale_fac_uVolts_per_count = (MCP3912_Vref * 1000000.f) / (8388607.0 * MCP3912_gain * 1.5 * 51.0); //MCP3912 datasheet page 34. Gain of InAmp = 80
    
    private int curInterface = INTERFACE_NONE;//HANUZ INTERFACE NADARE 

    private DataPacket_ADS1299 dataPacket;

    private boolean checkingImpedance = false;

    public int[] impedanceArray = new int[NCHAN_BITALINO + 1];

    private int sampleRate = (int)fsHzBLE;

    public float getSampleRate() {
        return fsHzBLE;
    }

    public float get_scale_fac_uVolts_per_count() {
        return scale_fac_uVolts_per_count;
    }

    public boolean isCheckingImpedance() { return checkingImpedance; }

    public void overrideCheckingImpedance(boolean val) { checkingImpedance = val; }
    public int getInterface() {
        return curInterface;
    }
    public boolean isBLE () {
        return curInterface == INTERFACE_HUB_BLE;
    }

    public boolean isPortOpen() {
        return hub.isPortOpen();
    }

     private PApplet mainApplet;

     Bitalino() {};
     Bitalino(PApplet applet){
        mainApplet = applet;

        initDataPackets(nEEGValuesPerPacket, nAuxValuesPerPacket);
     }

     public void initDataPackets(int _nEEGValuesPerPacket, int _nAuxValuesPerPacket) {
        nEEGValuesPerPacket = _nEEGValuesPerPacket;
        nAuxValuesPerPacket = _nAuxValuesPerPacket;
        // For storing data into
        dataPacket = new DataPacket_ADS1299(nEEGValuesPerPacket, nAuxValuesPerPacket);  //this should always be 8 channels
        for(int i = 0; i < nEEGValuesPerPacket; i++) {
            dataPacket.values[i] = 0;
        }
        for(int i = 0; i < nAuxValuesPerPacket; i++){
            dataPacket.auxValues[i] = 0;
        }
    }

    public void processImpedance(JSONObject json) {
        int code = json.getInt(TCP_JSON_KEY_CODE);
        if (code == RESP_SUCCESS_DATA_IMPEDANCE) {
            int channel = json.getInt(TCP_JSON_KEY_CHANNEL_NUMBER);
            if (channel < 5) {
                int value = json.getInt(TCP_JSON_KEY_IMPEDANCE_VALUE);
                impedanceArray[channel] = value;
            }
        }
    }

    public void setSampleRate(int _sampleRate) {
        sampleRate = _sampleRate;
        hub.setSampleRate(sampleRate);
        println("Setting sample rate for Bitalino to " + sampleRate + "Hz");
    }

    public void setInterface(int _interface) {
        curInterface = _interface;
        if (isBLE()) {
            setSampleRate((int)fsHzBLE);
            if (_interface == INTERFACE_HUB_BLE) {
                hub.setProtocol(PROTOCOL_BLE);
            } else {
                hub.setProtocol(PROTOCOL_BLED112);
            }
            // hub.searchDeviceStart();
        }
    }

    public int closePort() {
        hub.disconnectBLE();
        return 0;
    }

    void startDataTransfer(){
        hub.changeState(HubState.NORMAL);  // make sure it's now interpretting as binary
        println("Bitalino: startDataTransfer(): sending \'" + command_startBinary);
        if (checkingImpedance) {
            impedanceStop();
            delay(100);
            hub.sendCommand('b');
        } else {
            hub.sendCommand('b');
        }
    }

    public void stopDataTransfer() {
        hub.changeState(HubState.STOPPED);  // make sure it's now interpretting as binary
        println("Bitalino: stopDataTransfer(): sending \'" + command_stop);
        hub.sendCommand('s');
    }

    public void changeChannelState(int Ichan, boolean activate) {
        if (isPortOpen()) {
            if ((Ichan >= 0)) {
                if (activate) {
                    println("Bitalino: changeChannelState(): activate: sending " + command_activate_channel[Ichan]);
                    hub.sendCommand(command_activate_channel[Ichan]);
                    w_timeSeries.hsc.powerUpChannel(Ichan);
                } else {
                    println("Bitalino: changeChannelState(): deactivate: sending " + command_deactivate_channel[Ichan]);
                    hub.sendCommand(command_deactivate_channel[Ichan]);
                    w_timeSeries.hsc.powerDownChannel(Ichan);
                }
            }
        }
    }

    public void impedanceStart() {
        println("Bitalino: impedance: START");
        JSONObject json = new JSONObject();
        json.setString(TCP_JSON_KEY_ACTION, TCP_ACTION_START);
        json.setString(TCP_JSON_KEY_TYPE, TCP_TYPE_IMPEDANCE);
        hub.writeJSON(json);
        checkingImpedance = true;
    }

    /**
      * Used to stop impedance testing. Some impedances may arrive after stop command
      *  was sent by this function.
      */
    public void impedanceStop() {
        println("Bitalino: impedance: STOP");
        JSONObject json = new JSONObject();
        json.setString(TCP_JSON_KEY_ACTION, TCP_ACTION_STOP);
        json.setString(TCP_JSON_KEY_TYPE, TCP_TYPE_IMPEDANCE);
        hub.writeJSON(json);
        checkingImpedance = false;
    }

    public void enterBootloaderMode() {
        println("Bitalino: Entering Bootloader Mode");
        hub.sendCommand(BITALINO_BOOTLOADER_MODE);
        delay(500);
        closePort();
        haltSystem();
        initSystemButton.setString("START SESSION");
        controlPanel.open();
        output("Bitalino now in bootloader mode! Enjoy!");
    }


};