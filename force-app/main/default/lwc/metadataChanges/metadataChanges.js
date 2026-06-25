import { LightningElement, track } from 'lwc';
import getMetadataChanges from '@salesforce/apex/MetadataChangesToolingApiController.getMetadataChanges';
import metadataList from './metadataList';

const COLUMNS = [
    { label: 'Type', fieldName: 'typeName', type: 'text' },
    { label: 'API Name', fieldName: 'apiName', type: 'text', wrapText: true },
    { label: 'Last Modified By', fieldName: 'lastModifiedByName', type: 'text' },
    {
        label: 'Last Modified Date',
        fieldName: 'lastModifiedDateTime',
        type: 'date',
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        }
    }
];

export default class MetadataChanges extends LightningElement {
    @track records = [];
    @track typeOptions = [];

    selectedType = '';
    typeInputValue = '';
    typeSearchTerm = '';
    isTypeSearching = false;
    typeDropdownOpen = false;

    apiNameFilter = '';
    changedAfter = '';
    selectedUserId = '';

    isLoading = false;
    hasSearched = false;
    error;

    columns = COLUMNS;
    userDisplayInfo = {
        primaryField: 'Name',
        additionalFields: ['Username']
    };
    userMatchingInfo = {
        primaryField: { fieldPath: 'Name', mode: 'contains' },
        additionalFields: [{ fieldPath: 'Username', mode: 'contains' }]
    };
    activeUserFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };

    connectedCallback() {
        this.typeOptions = this.buildTypeOptions();
    }

    get filteredTypeOptions() {
        const term = (this.typeSearchTerm || '').trim().toLowerCase();
        if (!term) {
            return this.typeOptions;
        }

        const exactMatches = this.typeOptions.filter((option) => this.matchesTypeOption(option, term));
        if (exactMatches.length) {
            return exactMatches;
        }

        const prefixMatches = this.typeOptions.filter((option) => this.startsWithTypeOption(option, term));
        if (prefixMatches.length) {
            return prefixMatches;
        }

        return this.typeOptions.filter((option) => this.includesTypeOption(option, term));
    }

    get noTypeMatches() {
        return this.filteredTypeOptions.length === 0;
    }

    get typeComboboxClass() {
        const base = 'slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click';
        return this.typeDropdownOpen ? `${base} slds-is-open` : base;
    }

    get typeInputDisplayValue() {
        return this.isTypeSearching ? this.typeSearchTerm : this.typeInputValue;
    }

    get hasSelectedType() {
        return Boolean(this.selectedType);
    }

    get hasRecords() {
        return this.records && this.records.length > 0;
    }

    get recordCountLabel() {
        const count = this.records.length;
        return `${count} record${count === 1 ? '' : 's'}`;
    }

    buildTypeOptions() {
        return metadataList.map((definition) => ({
            label: definition.name,
            value: definition.name
        }));
    }

    getTypeLabel(typeName) {
        if (!typeName) {
            return '';
        }
        const option = this.typeOptions.find((item) => item.value === typeName);
        return option ? option.label : typeName;
    }

    matchesTypeOption(option, term) {
        return option.label.toLowerCase() === term || option.value.toLowerCase() === term;
    }

    startsWithTypeOption(option, term) {
        return option.label.toLowerCase().startsWith(term) || option.value.toLowerCase().startsWith(term);
    }

    includesTypeOption(option, term) {
        return option.label.toLowerCase().includes(term) || option.value.toLowerCase().includes(term);
    }

    handleTypeFocus(event) {
        this.isTypeSearching = true;
        this.typeSearchTerm = '';
        this.typeDropdownOpen = true;
        event.target.select();
    }

    handleTypeBlur() {
        requestAnimationFrame(() => {
            this.isTypeSearching = false;
            this.typeDropdownOpen = false;
            this.typeSearchTerm = '';
            this.setTypeInputValue(this.getTypeLabel(this.selectedType));
        });
    }

    handleTypeInput(event) {
        const searchTerm = event.target.value;
        this.typeSearchTerm = searchTerm;
        this.isTypeSearching = true;
        this.typeDropdownOpen = true;
        if (!searchTerm) {
            this.selectedType = '';
            this.typeInputValue = '';
        }
    }

    handleTypeSelect(event) {
        event.preventDefault();
        const value = event.currentTarget.dataset.value;
        if (value) {
            this.selectedType = value;
            this.typeSearchTerm = '';
            this.isTypeSearching = false;
            this.setTypeInputValue(this.getTypeLabel(value));
        }
        this.typeDropdownOpen = false;
    }

    handleTypeClear(event) {
        event.preventDefault();
        this.selectedType = '';
        this.typeSearchTerm = '';
        this.isTypeSearching = false;
        this.typeDropdownOpen = false;
        this.setTypeInputValue('');
    }

    setTypeInputValue(value) {
        this.typeInputValue = value;
        const input = this.template.querySelector('[data-type-input]');
        if (input) {
            input.value = value;
        }
    }

    handleApiNameChange(event) {
        this.apiNameFilter = event.detail.value;
    }

    handleChangedAfterChange(event) {
        this.changedAfter = event.detail.value;
    }

    handleUserChange(event) {
        this.selectedUserId = event.detail.recordId || '';
    }

    async handleGetChanges() {
        this.isLoading = true;
        this.hasSearched = false;
        this.error = undefined;
        this.records = [];

        try {
            const definitions = this.selectedType
                ? metadataList.filter((definition) => definition.name === this.selectedType)
                : metadataList;
            this.records = await getMetadataChanges({
                definitions: definitions,
                apiNameFilter: this.apiNameFilter,
                changedAfter: this.changedAfter,
                lastModifiedById: this.selectedUserId || null
            });
            this.hasSearched = true;
        } catch (err) {
            this.error = this.reduceError(err);
            this.hasSearched = true;
        } finally {
            this.isLoading = false;
        }
    }

    reduceError(error) {
        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }
        if (error?.body?.message) {
            return error.body.message;
        }
        if (error?.message) {
            return error.message;
        }
        return 'Unexpected error retrieving changes.';
    }
}
