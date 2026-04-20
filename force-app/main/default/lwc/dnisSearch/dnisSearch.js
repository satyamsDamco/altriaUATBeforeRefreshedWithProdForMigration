import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import { IsConsoleNavigation, getFocusedTabInfo, setTabLabel, disableTabClose } from 'lightning/platformWorkspaceApi';

import initializePage from '@salesforce/apex/DNISSearchLwcController.initializePage';
import searchOnLoad from '@salesforce/apex/DNISSearchLwcController.searchOnLoad';
import searchByOperatingCompany from '@salesforce/apex/DNISSearchLwcController.searchByOperatingCompany';

export default class DnisSearch extends NavigationMixin(LightningElement) {
    @track opCompany = '--Select DNIS--';
    @track opCompanyOptions = [];
    @track errorMessage = '';
    @track isLoading = true;

    remotenumber;
    called;
    ucid;
    initialized = false;
    autoSearched = false;

    @wire(CurrentPageReference)
    currentPageReference(pageRef) {
        if (pageRef) {
            this.remotenumber = pageRef.state?.c__remotenumber || pageRef.state?.remotenumber || '';
            this.called = pageRef.state?.c__called || pageRef.state?.called || '';
            this.ucid = pageRef.state?.c__ucid || pageRef.state?.ucid || '';

            if (!this.initialized) {
                this.initialized = true;
                this.boot();
            }
        }
    }

    @wire(IsConsoleNavigation) isConsoleNavigation;

    connectedCallback() {
        this.clearCookie('tranid');
        this.clearCookie('customerRecType');
    }

    disconnectedCallback() {
        try {
            localStorage.removeItem('firstLoad');
        } catch (e) {
            // no-op
        }
    }

    async boot() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            await this.handleConsoleSetup();

            const result = await initializePage({
                remotenumber: this.remotenumber,
                called: this.called,
                ucid: this.ucid
            });

            this.opCompanyOptions = result.opCompanyList || [];

            if (result.shouldAutoSearch && !this.autoSearched) {
                this.autoSearched = true;
                await this.executeAutoSearch();
                return;
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleConsoleSetup() {
        try {
            if (this.isConsoleNavigation?.data) {
                const focusedTab = await getFocusedTabInfo();
                if (focusedTab?.tabId) {
                    await setTabLabel(focusedTab.tabId, 'DNIS Search');
                    await disableTabClose(focusedTab.tabId, false);
                }
            }
        } catch (e) {
            // Keep page functional even if console API is unavailable
        }
    }

    handleChange(event) {
        this.opCompany = event.detail.value;
        this.errorMessage = '';
    }

    async executeAutoSearch() {
        this.isLoading = true;
        this.errorMessage = '';

        try {
            const result = await searchOnLoad({
                remotenumber: this.remotenumber,
                called: this.called,
                ucid: this.ucid
            });

            if (result?.success) {
                this.applyTransactionCookies(result.tranid, result.customerType);
                this.navigateToUrl(result.redirectUrl);
            } else {
                this.errorMessage = result?.message || 'Something went wrong.';
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    async handleSelect() {
        this.errorMessage = '';

        if (!this.opCompany || this.opCompany === '--Select DNIS--') {
            this.errorMessage = 'Please select Operating Company';
            return;
        }

        this.isLoading = true;

        try {
            const result = await searchByOperatingCompany({
                operatingCompanyId: this.opCompany
            });

            if (result?.success) {
                this.applyTransactionCookies(result.tranid, result.customerType);
                this.navigateToUrl(result.redirectUrl);
            } else {
                this.errorMessage = result?.message || 'Something went wrong.';
            }
        } catch (error) {
            this.errorMessage = this.reduceError(error);
        } finally {
            this.isLoading = false;
        }
    }

    applyTransactionCookies(tranid, customerType) {
        this.clearCookie('tranid');
        this.clearCookie('customerRecType');

        if (tranid) {
            this.setCookie('tranid', tranid);
        }

        if (customerType === 'Consumer') {
            this.setCookie('customerRecType', 'consumer');
        } else if (customerType === 'Trade Customer') {
            this.setCookie('customerRecType', 'trade');
        }
    }

    setCookie(name, value) {
        document.cookie = `${name}=${value}; path=/; SameSite=Lax`;
    }

    clearCookie(name) {
        document.cookie = `${name}=; expires=Wed, 01 Jan 2020 00:00:00 GMT; path=/; SameSite=Lax`;
    }

    navigateToUrl(url) {
        if (!url) {
            return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: url
            }
        });
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map(e => e.message).join(', ');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unknown error occurred.';
    }
}