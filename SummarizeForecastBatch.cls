global with sharing class SummarizeForecastBatch implements Database.Batchable<SObject>, Database.Stateful {
    global SummarizeForecastBatch() {}
    
    private AccountInfo accountInfo = null;
    
    global Database.QueryLocator start(Database.BatchableContext context) {
        String query = 'SELECT Id FROM Account';
        System.debug(query);
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext context, List<Account> scope) {
         
        List<ForecastSummary__c> summaryForecastList = new List<ForecastSummary__c>();
     
        List<ForecastSummary__c> forecastSummaryList = new List<ForecastSummary__c>();
        
        List<AggregateResult> aggregateResultByAccountList = [
            SELECT Account__c, SUM(Value__c) Value
            FROM Forecast__c
            WHERE Account__c IN: scope
            GROUP BY Account__c
        ];
        
        List<AggregateResult> aggregateResultByAccountProductList = [
            SELECT Account__c, Product__c, SUM(Value__c) Value
            FROM Forecast__c
            WHERE Account__c IN: scope
            GROUP BY Account__c, Product__c
        ]; 
        
        System.debug(aggregateResultByAccountProductList);
        for (AggregateResult accountResult : aggregateResultByAccountList) {
            Decimal totalValue = (Decimal)accountResult.get('Value');
            System.debug(totalValue);
            summaryForecastList.add(new ForecastSummary__c(
            	Key__c = (String)accountResult.get('Account__c'),
                Account__c = (Id)accountResult.get('Account__c'),
                Value__c = totalValue
            ));
            
            if (this.accountInfo == null || totalValue > this.accountInfo.Value) {
                this.accountInfo = new AccountInfo(
                	(String)accountResult.get('Account__c'),
                    totalValue
                );
                System.debug(this.accountInfo);
            }
            System.debug(summaryForecastList);
        }
        
        for (AggregateResult accountProductResult : aggregateResultByAccountProductList) {
            forecastSummaryList.add(new ForecastSummary__c(
            	Key__c = (String)accountProductResult.get('Account__c') + ' ' + (String)accountProductResult.get('Product__c'),
                Account__c = (Id)accountProductResult.get('Account__c'),
                Product__c = (Id)accountProductResult.get('Product__c'),
                Value__c = (Decimal)accountProductResult.get('Value')
            ));
            System.debug(forecastSummaryList);
        }
        
        System.debug(forecastSummaryList);
        upsert forecastSummaryList Key__c;
    }
    
    global void finish(Database.BatchableContext context) {
        Account account = [
            SELECT Id, Name
            FROM Account
            WHERE Id =: this.accountInfo.AccountId
        ];
        
        System.debug( 'account: ' + this.accountInfo.AccountId);
        
        ForecastEmailNotification__c forecastEmailSettings = ForecastEmailNotification__c.getValues('ForecastAccountProduct');
        System.debug(forecastEmailSettings);
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        System.debug(mail);
        mail.setToAddresses(new List<String> {forecastEmailSettings.ToAddress__c});
        mail.setSubject(forecastEmailSettings.Subject__c);
        
        String body = String.format(
            '{0}. Account {1} had a total forecast of {2}',
            new List<Object> {forecastEmailSettings.Body__c, account.Name, this.accountInfo.Value}
        );

        mail.setPlainTextBody(body);
        System.debug(body);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {mail});
    } 
    
    public class AccountInfo {
        public Id AccountId {get; set;}
        public Decimal Value {get; set;}
        
        public AccountInfo(Id accountId, Decimal value) {
            this.AccountId = accountId;
            this.Value = value;
        }
    }
    
}
