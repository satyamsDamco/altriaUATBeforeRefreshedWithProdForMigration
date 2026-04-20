@IsTest
private class TraceCodeHelperTest {

    @testSetup
    static void setupData() {
        List<SObject> fwList = new List<SObject>();

        fwList.add(makeFinancialWeek('0117', Date.today().addDays(-400)));
        fwList.add(makeFinancialWeek('0118', Date.today().addDays(-350)));
        fwList.add(makeFinancialWeek('0219', Date.today().addDays(-300)));
        fwList.add(makeFinancialWeek('0320', Date.today().addDays(-250)));
        fwList.add(makeFinancialWeek('0421', Date.today().addDays(-200)));
        fwList.add(makeFinancialWeek('0522', Date.today().addDays(-180)));
        fwList.add(makeFinancialWeek('0623', Date.today().addDays(-160)));
        fwList.add(makeFinancialWeek('0724', Date.today().addDays(-140)));
        fwList.add(makeFinancialWeek('0825', Date.today().addDays(-120)));
        fwList.add(makeFinancialWeek('0926', Date.today().addDays(-100)));
        fwList.add(makeFinancialWeek('1027', Date.today().addDays(-80)));
        fwList.add(makeFinancialWeek('1128', Date.today().addDays(-60)));
        fwList.add(makeFinancialWeek('1229', Date.today().addDays(-40)));
        fwList.add(makeFinancialWeek('5203', Date.today().addDays(-30)));
        fwList.add(makeFinancialWeek('4403', Date.today().addDays(-25)));
        fwList.add(makeFinancialWeek('2303', Date.today().addDays(-20)));
        insert fwList;

        List<SObject> cfList = new List<SObject>();
        cfList.add(makeCounterfeit('COUNTER123', Date.today().addDays(-50), true));
        cfList.add(makeCounterfeit('COUNTEREMPTY', null, true));
        insert cfList;

        List<SObject> cigList = new List<SObject>();
        cigList.add(makeCigaretteModule('123', 'AS'));
        cigList.add(makeCigaretteModule('ABC', 'AS'));
        cigList.add(makeCigaretteModule('123', 'TP'));
        cigList.add(makeCigaretteModule('000', 'TP'));
        insert cigList;

        List<SObject> mtList = new List<SObject>();
        mtList.add(makeMatrix('GP', 9, 'V'));
        mtList.add(makeMatrix('GP', 11, 'A'));
        mtList.add(makeMatrix('GP', 12, 'A'));
        mtList.add(makeMatrix('PT', 12, 'S'));
        mtList.add(makeMatrix('PT', 12, 'O'));
        mtList.add(makeMatrix('PT', 12, 'K'));
        mtList.add(makeMatrix('PT', 12, 'X'));
        mtList.add(makeMatrix('PT', 12, 'H'));
        mtList.add(makeMatrix('PT', 12, 'M'));
        insert mtList;
    }

    private static SObject makeFinancialWeek(String fiscalWeek, Date prodDate) {
        SObject sob = Schema.getGlobalDescribe().get('Financial_Week__c').newSObject();
        sob.put('FISCAL_WEEK_YEAR__c', fiscalWeek);
        sob.put('PRODUCTION_DATE__c', prodDate.format());
        return sob;
    }

    private static SObject makeCounterfeit(String code, Date prodDate, Boolean activeVal) {
        SObject sob = Schema.getGlobalDescribe().get('CounterfeitTraceCode__c').newSObject();
        sob.put('Trace_Code__c', code);
        sob.put('Production_Date__c', prodDate);
        sob.put('IsActive__c', activeVal);
        return sob;
    }

    private static SObject makeCigaretteModule(String code, String plc) {
        SObject sob = Schema.getGlobalDescribe().get('CigaretteModule__c').newSObject();
        sob.put('Cigarette_Code__c', code);
        sob.put('ProductLineCode__c', plc);
        sob.put('Active__c', true);

        // Required fields from your org
       // sob.put('COLD_STORAGE__c', false);
        

        return sob;
    }

    private static SObject makeMatrix(String plc, Integer lenVal, String pos1) {
        SObject sob = Schema.getGlobalDescribe().get('Tracecode_Matrix_Table__c').newSObject();
        sob.put('Product_Line_Code__c', plc);
        sob.put('Character_Length__c', lenVal);
        sob.put('Position_1__c', pos1);
        return sob;
    }

    @IsTest
    static void testUtilityMethods() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.JulianDateChecker('001', 2024);
        h.JulianDateChecker('366', 2024);
        h.JulianDateChecker('366', 2023);
        h.JulianDateChecker('AAA', 2024);

        h.sixCharacterProductDate('WA1234');
        h.sixCharacterProductDate('XA9999');
        h.sixCharacterProductDate('ZZ9999');

        h.convertProductDate('1/1/2024');
        h.nextDay('01/01/2024', 'Monday');
        h.mondayDate('2024', '1');
        h.mondayDate('2024', '10');

        TraceCodeHelper.checkCounterfeitTraceCode('COUNTER123');
        TraceCodeHelper.checkCounterfeitTraceCode('UNKNOWNCODE');
        Test.stopTest();
    }

    @IsTest
    static void testProductDateCalculatorBranches() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.ProductDateCalculator('AAAA412300', 'IQ');
        h.ProductDateCalculator('AAAA9AA000', 'IQ');

        h.ProductDateCalculator('M', 'TDNP');
        h.ProductDateCalculator('WA1234', 'TDNP');
        h.ProductDateCalculator('WAX1234', 'TDNP');
        h.ProductDateCalculator('D261N0912', 'TDNP');

        h.ProductDateCalculator('A1234B567890', 'PT');
        h.ProductDateCalculator('A1234X567890', 'PT');

        h.ProductDateCalculator('D261U0912', 'SNP');
        h.ProductDateCalculator('Z261U0912', 'SNP');

        h.ProductDateCalculator('D261U0912', 'TDNS');
        h.ProductDateCalculator('Z261U0912', 'TDNS');

        h.ProductDateCalculator('A123X4ABC', 'AS');
        h.ProductDateCalculator('A123X4ABC', 'GP');
        h.ProductDateCalculator('A999X9ABC', 'GP');
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationCounterfeitAndBasic() {
        TraceCodeHelper h = new TraceCodeHelper();

        Case c = new Case(Subject = 'Trace Test Case');
        insert c;

        Test.startTest();
        h.traceCodeValidation('AS', 'COUNTER123', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('AS', 'COUNTEREMPTY', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('EV', '123', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('EV', 'BG0117C', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('N', 'ANYTHING', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('NULL', 'ANYTHING', 'ZZ', 'NONCAS', c);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationCASBranches() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('AS', 'A123B4512345678901', 'PMUSA', 'CAS', null);
        h.traceCodeValidation('AS', 'A1234567', 'USST', 'CAS', null);
        h.traceCodeValidation('AS', '123X1', 'JMC', 'CAS', null);
        h.traceCodeValidation('TP', 'N123X1X01', 'ZZ', 'CAS', null);
        h.traceCodeValidation('TP', 'L123X1000', 'ZZ', 'CAS', null);
        h.traceCodeValidation('TP', 'A123456789', 'ZZ', 'CAS', null);
        h.traceCodeValidation('TP', 'A123X1B12345678', 'ZZ', 'CAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationASAndTP() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('AS', 'V123X4123', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('AS', 'V123X412311', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'W123X4123', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'N123X401', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'F123X401', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'Y12345X67', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'J12345X67', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TP', 'L123X4000', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationGP() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('GP', '12BCH1BL', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('GP', 'BERBL', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('GP', 'A123X401', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('GP', 'V200X88P4', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('GP', 'A200X123456', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('GP', 'A200X1234567', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationPT() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('PT', 'BLBA', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'L011', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'L12345', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'EB', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'XBLBAXX', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'S123X1292359', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('PT', 'BELB1', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationEC() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('EC', 'A1201A20', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('EC', 'AA0118C', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('EC', 'A52123', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('EC', 'A1234501188', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationDNUAAndNC() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('DNUA', '01012024', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('DNUA', '01JAN2024', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('DNUA', '0123456789', 'ZZ', 'NONCAS', null);

        h.traceCodeValidation('NC', '120115YL', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('NC', '120115YLA', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationTDNP_SNP_TDNS_IQ() {
        TraceCodeHelper h = new TraceCodeHelper();

        Test.startTest();
        h.traceCodeValidation('TDNP', 'M', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TDNP', 'WA1234', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TDNP', 'WAB1234', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TDNP', 'D261N0912', 'ZZ', 'NONCAS', null);

        h.traceCodeValidation('SNP', 'WAB1234', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('SNP', 'D261N0912', 'ZZ', 'NONCAS', null);

        h.traceCodeValidation('TDNS', 'WAB1234', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('TDNS', 'D261N0912', 'ZZ', 'NONCAS', null);

        h.traceCodeValidation('IQ', 'AAAA412300', 'ZZ', 'NONCAS', null);
        h.traceCodeValidation('IQ', '123', 'ZZ', 'NONCAS', null);
        Test.stopTest();
    }

    @IsTest
    static void testTraceCodeValidationUSST9DigitBranches() {
        TraceCodeHelper h = new TraceCodeHelper();

        Case c = new Case(Subject = 'USST Branch Case');
        insert c;

        Test.startTest();
        h.traceCodeValidation('SP', '5044H2236', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5090F1508', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5045E1508', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5266D2245', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5091B1508', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5370B1508', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('SP', '5203Z0700', 'ZZ', 'NONCAS', c);

        h.traceCodeValidation('PC', 'N123N2359', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('DS', 'R123K2359', 'ZZ', 'NONCAS', c);
        h.traceCodeValidation('UU', 'Y123Y2359', 'ZZ', 'NONCAS', c);
        Test.stopTest();
    }

    @IsTest
    static void testDirectPublicMethodCalls() {
        TraceCodeHelper h1 = new TraceCodeHelper();
        TraceCodeHelper h2 = new TraceCodeHelper();

        Test.startTest();
        h1.traceCodeValidation('TP', 'L123X4000', 'ZZ', 'NONCAS', null);
        h1.methodOne();

        h2.traceCodeValidation('TP', 'N1234512N', 'ZZ', 'NONCAS', null);
        h2.methodTwo();
        Test.stopTest();
    }
}