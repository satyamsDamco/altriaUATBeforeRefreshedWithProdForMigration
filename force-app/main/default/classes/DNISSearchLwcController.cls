public with sharing class DNISSearchLwcController {

    public class SelectOptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public SelectOptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class InitResponse {
        @AuraEnabled public List<SelectOptionWrapper> opCompanyList;
        @AuraEnabled public String customerNumber;
        @AuraEnabled public String tollNumber;
        @AuraEnabled public String ucid;
        @AuraEnabled public Boolean shouldAutoSearch;

        public InitResponse() {
            opCompanyList = new List<SelectOptionWrapper>();
            customerNumber = '';
            tollNumber = '';
            ucid = '';
            shouldAutoSearch = false;
        }
    }

    public class SearchResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String tranid;
        @AuraEnabled public String customerType;
        @AuraEnabled public String redirectUrl;

        public SearchResponse() {
            success = false;
            message = '';
            tranid = '';
            customerType = '';
            redirectUrl = '';
        }
    }

    @AuraEnabled(cacheable=true)
    public static InitResponse initializePage(String remotenumber, String called, String ucid) {
        InitResponse response = new InitResponse();

        response.customerNumber = String.isNotBlank(remotenumber)
            ? EncodingUtil.urlDecode(remotenumber, 'UTF-8')
            : '';

        response.tollNumber = String.isNotBlank(called) ? called : '';
        response.ucid = String.isNotBlank(ucid) ? ucid : '';

        response.opCompanyList.add(new SelectOptionWrapper('--Select DNIS--', '--Select DNIS--'));

        List<Operating_Company__c> opCompanies = [
            SELECT Id, Default_TFN__c, OperatingCompany__c, Trade__c
            FROM Operating_Company__c
            WHERE Active__c = true
              AND Default_TFN__c != null
            ORDER BY OperatingCompany__c ASC
        ];

        for (Operating_Company__c temp : opCompanies) {
            if (String.isNotBlank(temp.OperatingCompany__c)) {
                response.opCompanyList.add(
                    new SelectOptionWrapper(temp.OperatingCompany__c, (String)temp.Id)
                );
            }
        }

        response.shouldAutoSearch =
            String.isNotBlank(response.customerNumber) &&
            String.isNotBlank(response.tollNumber);

        return response;
    }

    @AuraEnabled
    public static SearchResponse searchOnLoad(String remotenumber, String called, String ucid) {
        SearchResponse response = new SearchResponse();

        String customerNumber = String.isNotBlank(remotenumber)
            ? EncodingUtil.urlDecode(remotenumber, 'UTF-8')
            : '';
        String tollNumber = String.isNotBlank(called) ? called : '';
        String localUcid = String.isNotBlank(ucid) ? ucid : '';

        if (String.isBlank(customerNumber) || String.isBlank(tollNumber)) {
            response.message = 'Required call parameters are missing.';
            return response;
        }

        List<TFN__c> opCompany = [
            SELECT Id, Operating_Company__c, Operating_Company__r.Trade__c, DNIS__c
            FROM TFN__c
            WHERE Active__c = true
              AND (Toll_Free_Number__c = :tollNumber OR DNIS__c = :tollNumber)
            LIMIT 1
        ];

        if (opCompany.isEmpty()) {
            response.message = 'No active DNIS/TFN mapping found.';
            return response;
        }

        Transaction_Management__c transmgmObj = new Transaction_Management__c();
        transmgmObj.Operating_Company__c = opCompany[0].Operating_Company__c;
        transmgmObj.Start_Date_Time__c = System.now();
        transmgmObj.TFN__c = opCompany[0].Id;
        transmgmObj.ANI__c = customerNumber;
        transmgmObj.ContactChannel__c = System.Label.ContactChannel;
        transmgmObj.CallID__c = localUcid;

        Database.UpsertResult upsRst = Database.upsert(transmgmObj);

        if (upsRst != null && upsRst.isSuccess()) {
            String tranid = upsRst.getId();
            String customerType = opCompany[0].Operating_Company__r.Trade__c ? 'Trade Customer' : 'Consumer';

            response.success = true;
            response.tranid = tranid;
            response.customerType = customerType;

            if (customerType == 'Consumer') {
                response.redirectUrl = '/apex/ConsumerSearch?tranid=' + tranid + '&customerNumber=' + EncodingUtil.urlEncode(customerNumber, 'UTF-8');
            } else {
                response.redirectUrl = '/apex/TradeSearch?tranid=' + tranid + '&customerNumber=' + EncodingUtil.urlEncode(customerNumber, 'UTF-8');
            }
        } else {
            response.message = 'Unable to create transaction record.';
        }

        return response;
    }

    @AuraEnabled
    public static SearchResponse searchByOperatingCompany(String operatingCompanyId) {
        SearchResponse response = new SearchResponse();

        if (String.isBlank(operatingCompanyId) || operatingCompanyId == '--Select DNIS--') {
            response.message = 'Please select Operating Company';
            return response;
        }

        List<Operating_Company__c> opList = [
            SELECT Id, Default_TFN__c, OperatingCompany__c, Trade__c
            FROM Operating_Company__c
            WHERE Id = :operatingCompanyId
            LIMIT 1
        ];

        if (opList.isEmpty()) {
            response.message = 'Selected Operating Company not found.';
            return response;
        }

        Operating_Company__c opObj = opList[0];

        Transaction_Management__c transmgmObj = new Transaction_Management__c();
        transmgmObj.Operating_Company__c = opObj.Id;
        transmgmObj.Start_Date_Time__c = System.now();
        transmgmObj.TFN__c = opObj.Default_TFN__c;

        Database.UpsertResult upsRst = Database.upsert(transmgmObj);

        if (upsRst != null && upsRst.isSuccess()) {
            String tranid = upsRst.getId();
            String customerType = opObj.Trade__c ? 'Trade Customer' : 'Consumer';

            response.success = true;
            response.tranid = tranid;
            response.customerType = customerType;

            if (customerType == 'Consumer') {
                response.redirectUrl = '/apex/ConsumerSearch?tranid=' + tranid;
            } else {
                response.redirectUrl = '/apex/TradeSearch?tranid=' + tranid;
            }
        } else {
            response.message = 'Unable to create transaction record.';
        }

        return response;
    }
}